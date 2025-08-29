{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption types mkIf mkMerge;
  cfg = config.services.bunMonorepo;

  # Helper to sanitize names for systemd unit IDs
  sanitize = name:
    lib.strings.toLower (
      lib.strings.replaceStrings [ " " "/" "\\" ":" ] [ "-" "-" "-" "-" ] name
    );

  # Fetch repo at eval time to discover apps and their config.
  repoSnapshot = if (cfg.enable && cfg.repoUrl != null) then
    (builtins.fetchGit {
      url = cfg.repoUrl;
      # Prefer using a branch/ref; users can pin with 'rev' if desired.
      ref = cfg.ref;
      # leave rev unset for tracking ref
    })
  else null;

  appsDirPath = if (cfg.enable && cfg.repoUrl != null) then "${repoSnapshot}/${cfg.appsDir}" else null;

  # Build a list of app descriptors from apps/*/bun-app.json
  apps = if (cfg.enable && cfg.repoUrl != null) then (
    let
      entries = builtins.readDir appsDirPath;
      dirNames = builtins.attrNames (lib.filterAttrs (_: v: v == "directory") entries);
      hasBunJson = d: builtins.pathExists ("${appsDirPath}/${d}/bun-app.json");
      parseApp = d:
        let
          appJson = builtins.fromJSON (builtins.readFile ("${appsDirPath}/${d}/bun-app.json"));
          # Ensure required fields exist; basic validation
          nm = if appJson ? name then appJson.name else d;
          dm = if appJson ? domain then appJson.domain else throw "bun-app.json in ${d} missing 'domain'";
          pcmd = if appJson ? prod then appJson.prod else throw "bun-app.json in ${d} missing 'prod'";
        in {
          dir = d;
          name = nm;
          domain = dm;
          prod = pcmd;
        };
    in
      map parseApp (lib.filter hasBunJson dirNames)
  ) else [];

  # Assign ports deterministically starting at basePort
  appsWithPorts = if (cfg.enable && cfg.repoUrl != null) then
    (lib.imap0 (i: a: a // { port = cfg.basePort + i; }) apps)
  else [];

  # Build Caddy virtualHosts attrset
  caddyVhosts = if (cfg.enable && cfg.repoUrl != null) then
    (lib.listToAttrs (map (a: {
      name = a.domain;
      value = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${toString a.port}
        '';
      };
    }) appsWithPorts))
  else {};

  # Helper: prestart script to clone/update repo and install deps for an app
  prestartScript = a: pkgs.writeShellScript "bun-prestart-${sanitize a.name}" ''
    set -euo pipefail
    install -d -m 0755 -o ${cfg.user} -g ${cfg.group} /var/lib/bun-monorepo
    if [ ! -d /var/lib/bun-monorepo/repo/.git ]; then
      ${pkgs.git}/bin/git clone --depth 1 --branch ${lib.escapeShellArg cfg.ref} ${lib.escapeShellArg cfg.repoUrl} /var/lib/bun-monorepo/repo
    else
      ${pkgs.git}/bin/git -C /var/lib/bun-monorepo/repo fetch --depth 1 origin ${lib.escapeShellArg cfg.ref}
      ${pkgs.git}/bin/git -C /var/lib/bun-monorepo/repo reset --hard origin/${lib.escapeShellArg cfg.ref}
    fi
    cd /var/lib/bun-monorepo/repo/${cfg.appsDir}/${a.dir}
    # Install production deps. If no lockfile, this still succeeds.
    ${pkgs.bun}/bin/bun install --production --frozen-lockfile || ${pkgs.bun}/bin/bun install --production
  '';

  runScript = a: pkgs.writeShellScript "bun-run-${sanitize a.name}" ''
    set -euo pipefail
    cd /var/lib/bun-monorepo/repo/${cfg.appsDir}/${a.dir}
    export PORT=${toString a.port}
    export NODE_ENV=production
    # Use bash -lc to respect complex commands from bun-app.json prod field
    exec ${pkgs.bash}/bin/bash -lc ${lib.escapeShellArg a.prod}
  '';
in
{
  options.services.bunMonorepo = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable deployment of Bun monorepo apps with Caddy reverse proxy.";
    };

    repoUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "https://github.com/you/your-mono.git";
      description = "Git URL of the Bun apps monorepo to pull.";
    };

    ref = mkOption {
      type = types.str;
      default = "main";
      description = "Git branch or ref to track (e.g., main).";
    };

    appsDir = mkOption {
      type = types.str;
      default = "apps";
      description = "Relative path within the repo containing app folders.";
    };

    basePort = mkOption {
      type = types.port;
      default = 3000;
      description = "Base port; apps are assigned sequential ports starting here.";
    };

    user = mkOption {
      type = types.str;
      default = "bun-monorepo";
      description = "System user to run Bun apps.";
    };

    group = mkOption {
      type = types.str;
      default = "bun-monorepo";
      description = "System group to run Bun apps.";
    };

    caddyEmail = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "admin@example.com";
      description = "Email for Caddy's ACME/HTTPS certificates.";
    };

    env = mkOption {
      type = types.attrsOf types.str;
      default = {};
      example = { SOME_KEY = "value"; };
      description = "Extra environment variables passed to each app.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      users.groups.${cfg.group} = {};
      users.users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = "/var/lib/bun-monorepo";
        createHome = true;
      };

      # Open HTTP/HTTPS for Caddy
      networking.firewall.allowedTCPPorts = [ 80 443 ];

      # Ensure base directory exists
      systemd.tmpfiles.rules = [
        "d /var/lib/bun-monorepo 0755 ${cfg.user} ${cfg.group} -"
      ];
    }

    # Caddy configuration generated from apps
    (mkIf (cfg.repoUrl != null) {
      services.caddy = mkMerge [
        {
          enable = true;
          virtualHosts = caddyVhosts;
        }
        (mkIf (cfg.caddyEmail != null) { email = cfg.caddyEmail; })
      ];
    })

    # One systemd service per app
    (mkIf (cfg.repoUrl != null) {
      systemd.services = lib.listToAttrs (map (a: {
        name = "bun-app-" + sanitize a.name;
        value = {
          description = "Bun app ${a.name} (${a.domain})";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          serviceConfig = {
            Type = "simple";
            User = cfg.user;
            Group = cfg.group;
            Restart = "always";
            RestartSec = 3;
            WorkingDirectory = "/var/lib/bun-monorepo/repo/${cfg.appsDir}/${a.dir}";
            ExecStartPre = [ (prestartScript a) ];
            ExecStart = runScript a;
            Environment = (
              [ "PORT=${toString a.port}" "NODE_ENV=production" ]
              ++ (map (k: k + "=" + cfg.env.${k}) (builtins.attrNames cfg.env))
            );
          };
          path = [ pkgs.bun pkgs.git pkgs.bash ];
        };
      }) appsWithPorts);
    })
  ]);
}
