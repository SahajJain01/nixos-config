{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  bun = pkgs.bun;
  cfg = config.services.bunMonorepo;

  prepareScript = pkgs.writeShellScript "bun-app-prepare" ''
    set -euo pipefail
    if [ "$#" -lt 1 ]; then
      echo "usage: bun-app-prepare <instance>" >&2
      exit 1
    fi
    inst="$1"
    envfile="/etc/bun-apps/$inst.env"
    if [ ! -f "$envfile" ]; then
      echo "env file not found: $envfile" >&2
      exit 1
    fi
    # shellcheck disable=SC1090
    . "$envfile"

    # Require REPO and set defaults without relying on parameter-expansion tricks
    set +u
    if [ -z "$REPO" ]; then
      echo "Set REPO in $envfile" >&2
      exit 1
    fi
    if [ -z "$BRANCH" ]; then BRANCH=main; fi
    if [ -z "$SUBDIR" ]; then SUBDIR=.; fi
    use_mono="''${USE_MONOREPO:-0}"
    mono_root="''${MONOREPO_ROOT:-}"
    set -u

    if [ "$use_mono" = "1" ] && [ -n "$mono_root" ]; then
      workdir="$mono_root/$SUBDIR"
      if [ ! -d "$workdir" ]; then
        echo "Workdir not found: $workdir" >&2
        exit 1
      fi
    else
      basedir="/var/lib/bun-apps/$inst"
      srcdir="$basedir/src"
      workdir="$srcdir/$SUBDIR"

      mkdir -p "$basedir" "$srcdir"

      if [ ! -d "$srcdir/.git" ]; then
        echo "Cloning $REPO (branch $BRANCH) into $srcdir"
        git clone --depth 1 --branch "$BRANCH" "$REPO" "$srcdir"
      else
        echo "Updating repo in $srcdir"
        git -C "$srcdir" fetch --depth 1 origin "$BRANCH" || git -C "$srcdir" fetch origin "$BRANCH"
        git -C "$srcdir" checkout "$BRANCH"
        git -C "$srcdir" reset --hard "origin/$BRANCH" || git -C "$srcdir" pull --ff-only
      fi

      if [ ! -d "$workdir" ]; then
        echo "Workdir not found: $workdir" >&2
        exit 1
      fi
    fi

    echo "Installing dependencies with bun in $workdir"
    cd "$workdir"
    # Don't fail if lockfile types differ; let bun handle it
    ${bun}/bin/bun install || true
    set +u
    if [ -n "$BUILD_CMD" ]; then
      echo "Building with: $BUILD_CMD"
      bash -lc "$BUILD_CMD"
    fi
    set -u
  '';

  runScript = pkgs.writeShellScript "bun-app-run" ''
    set -euo pipefail
    if [ "$#" -lt 1 ]; then
      echo "usage: bun-app-run <instance>" >&2
      exit 1
    fi
    inst="$1"
    envfile="/etc/bun-apps/$inst.env"
    # shellcheck disable=SC1090
    . "$envfile"

    set +u
    if [ -z "$SUBDIR" ]; then SUBDIR=.; fi
    if [ -z "$PORT" ]; then PORT=3000; fi
    if [ -z "$START_CMD" ]; then START_CMD='bun run start'; fi
    set -u

    if [ "''${USE_MONOREPO:-0}" = "1" ] && [ -n "''${MONOREPO_ROOT:-}" ]; then
      workdir="$MONOREPO_ROOT/$SUBDIR"
    else
      workdir="/var/lib/bun-apps/$inst/src/$SUBDIR"
    fi
    cd "$workdir"

    echo "Starting $inst on port $PORT"
    export PORT
    exec bash -lc "exec $START_CMD"
  '';

  # Placeholders for new monorepo features; actual scripts defined in config phase
  monorepoSyncPlaceholder = 0;
in
{
  options.services.bunMonorepo = {
    enable = mkEnableOption "Bun monorepo auto-deployer";
    repoUrl = mkOption {
      type = types.str;
      description = "Git URL of the monorepo containing Bun apps";
    };
    branch = mkOption { type = types.str; default = "main"; };
    appsDir = mkOption { type = types.str; default = "apps"; };
    portBase = mkOption { type = types.int; default = 3000; };
    portRange = mkOption { type = types.int; default = 1000; };
    webhook = {
      enable = mkOption { type = types.bool; default = false; };
      listenAddress = mkOption { type = types.str; default = "127.0.0.1"; };
      port = mkOption { type = types.port; default = 8787; };
      tokenFile = mkOption { type = types.path; default = "/etc/bun-apps/webhook-secret"; };
      domain = mkOption { type = types.nullOr types.str; default = null; };
      path = mkOption { type = types.str; default = "/sync"; };
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.bunapps = {};
    users.users.bunapps = {
      isSystemUser = true;
      group = "bunapps";
      home = "/var/lib/bun-apps";
      createHome = true;
    };

    # Ensure required tools are available to the service
    environment.systemPackages = with pkgs; [ git bun jq ];

    # Caddy as reverse proxy; dynamic import of vhosts from /etc
    services.caddy = {
      enable = true;
      # Add a global import to allow deploy-bun to drop files under /etc/caddy/Caddyfile.d
      extraConfig = ''
        import /etc/caddy/Caddyfile.d/*.caddy
      '';
    };

    # Ensure directories exist
    environment.etc."caddy/Caddyfile.d/.keep".text = "";
    environment.etc."bun-apps/.keep".text = "";

    # Firewall ports should be handled at the host level.

    # Systemd template for Bun apps
    systemd.services."bun-app@" = {
      description = "Bun app instance %i";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "simple";
        User = "bunapps";
        Group = "bunapps";
        EnvironmentFile = "/etc/bun-apps/%i.env";
        # Create a per-instance state dir; %i is expanded by systemd
        StateDirectory = "bun-apps/%i";
        WorkingDirectory = "/var/lib/bun-apps/%i";
        ExecStartPre = ''${prepareScript} %i'';
        ExecStart = ''${runScript} %i'';
        Restart = "always";
        RestartSec = 3;
      };
      # Provide PATH with git and bun available
      path = [ pkgs.coreutils pkgs.bash pkgs.git bun ];
      # Journal logs make it easy: journalctl -u bun-app@myapp -f
      wantedBy = [ "multi-user.target" ];
    };

    # Monorepo sync service: runs at boot and on webhook
    systemd.services."bun-monorepo-sync" = {
      description = "Sync and deploy Bun monorepo apps";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = (pkgs.writeShellScript "bun-monorepo-sync" ''
          set -euo pipefail
          REPO_URL="${cfg.repoUrl}"
          BRANCH="${cfg.branch}"
          APPS_DIR="${cfg.appsDir}"
          PORT_BASE=${toString cfg.portBase}
          PORT_RANGE=${toString cfg.portRange}

          basedir="/var/lib/bun-monorepo"
          srcdir="$basedir/src"
          mkdir -p "$srcdir"

          if [ ! -d "$srcdir/.git" ]; then
            echo "Cloning $REPO_URL (branch $BRANCH) into $srcdir"
            git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$srcdir"
          else
            echo "Updating monorepo in $srcdir"
            git -C "$srcdir" fetch --depth 1 origin "$BRANCH" || git -C "$srcdir" fetch origin "$BRANCH"
            git -C "$srcdir" checkout "$BRANCH"
            git -C "$srcdir" reset --hard "origin/$BRANCH" || git -C "$srcdir" pull --ff-only
          fi

          shopt -s nullglob
          found=0
          for cfgf in "$srcdir/$APPS_DIR"/*/bun-app.json; do
            found=1
            dir="$(dirname "$cfgf")"
            name="$(jq -r '.name // empty' "$cfgf")"
            branchCfg="$(jq -r '.branch // empty' "$cfgf")"
            port="$(jq -r '.port // empty' "$cfgf")"
            start="$(jq -r '.start // empty' "$cfgf")"
            build="$(jq -r '.build // empty' "$cfgf")"
            domain="$(jq -r '.domain // empty' "$cfgf")"
            if [ -z "$name" ]; then echo "Skipping $cfgf: missing name" >&2; continue; fi
            relsub="${dir#"$srcdir/"}"
            if [ -z "$start" ] || [ "$start" = "null" ]; then start="bun run start"; fi
            if [ -z "$branchCfg" ] || [ "$branchCfg" = "null" ]; then branchUse="$BRANCH"; else branchUse="$branchCfg"; fi

            if [ -z "$port" ] || [ "$port" = "null" ]; then
              hash=$(echo -n "$name" | cksum | awk '{print $1}')
              port=$(( PORT_BASE + (hash % PORT_RANGE) ))
              tries=0
              while grep -R "^PORT=$port$" /etc/bun-apps/*.env 2>/dev/null | grep -q .; do
                port=$((port + 1))
                tries=$((tries + 1))
                if [ $tries -gt $PORT_RANGE ]; then
                  echo "Could not find free port for $name" >&2
                  break
                fi
              done
            fi

            mkdir -p /etc/bun-apps /etc/caddy/Caddyfile.d
            envfile="/etc/bun-apps/$name.env"
            cat >"$envfile" <<EOF
REPO=$REPO_URL
BRANCH=$branchUse
PORT=$port
SUBDIR=$relsub
START_CMD=$(printf %q "$start")
USE_MONOREPO=1
MONOREPO_ROOT=$srcdir
EOF
            if [ -n "$build" ] && [ "$build" != "null" ]; then
              echo "BUILD_CMD=$(printf %q "$build")" >> "$envfile"
            fi

            if [ -n "$domain" ] && [ "$domain" != "null" ]; then
              cat >"/etc/caddy/Caddyfile.d/$name.caddy" <<CAD
$domain {
  reverse_proxy 127.0.0.1:$port
}
CAD
            else
              rm -f "/etc/caddy/Caddyfile.d/$name.caddy"
            fi

            systemctl reload caddy || true
            systemctl start "bun-app@$name.service"
          done

          if [ "$found" = 0 ]; then
            echo "No apps found under $srcdir/$APPS_DIR" >&2
          fi
        '');
      };
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.coreutils pkgs.bash pkgs.git pkgs.jq bun ];
    };

    # Optional webhook to trigger sync via HTTP (secured by token)
    systemd.services."bun-monorepo-webhook" = lib.mkIf cfg.webhook.enable {
      description = "Bun monorepo webhook";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = ''${bun}/bin/bun -e "(async()=>{const f=process.env.TOKEN_FILE||'/etc/bun-apps/webhook-secret';const p=process.env.WEBHOOK_PATH||'/sync';const h=process.env.LISTEN_ADDR||'127.0.0.1';const port=Number(process.env.LISTEN_PORT||8787);async function t(){try{return (await Bun.file(f).text()).trim()}catch{return ''}};Bun.serve({hostname:h,port,async fetch(req){const u=new URL(req.url);if(req.method!=='POST'||u.pathname!==p)return new Response('Not Found',{status:404});const s=req.headers.get('x-webhook-token')||u.searchParams.get('token')||'';const e=await t();if(e&&s!==e)return new Response('Unauthorized',{status:401});try{const r=Bun.spawnSync(['/run/current-system/sw/bin/systemctl','start','bun-monorepo-sync.service']);if(r.success)return new Response('ok\n');return new Response(r.stderr.toString(),{status:500})}catch(e){return new Response('error\n',{status:500})}}})})()"'';
        Restart = "on-failure";
        RestartSec = 2;
      };
      environment = {
        TOKEN_FILE = cfg.webhook.tokenFile;
        WEBHOOK_PATH = cfg.webhook.path;
        LISTEN_ADDR = cfg.webhook.listenAddress;
        LISTEN_PORT = toString cfg.webhook.port;
      };
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.coreutils bun ];
    };

    # Optional: expose webhook via Caddy if a domain is provided
    environment.etc."caddy/Caddyfile.d/bun-monorepo-webhook.caddy" = lib.mkIf (cfg.webhook.enable && cfg.webhook.domain != null) {
      text = ''
        ${cfg.webhook.domain} {
          reverse_proxy ${cfg.webhook.listenAddress}:${toString cfg.webhook.port}
        }
      '';
    };
  };
}
