{ config, lib, pkgs, ... }:
let
  bun = pkgs.bun;

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
    set -u

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

    workdir="/var/lib/bun-apps/$inst/src/$SUBDIR"
    cd "$workdir"

    echo "Starting $inst on port $PORT"
    export PORT
    exec bash -lc "exec $START_CMD"
  '';

  deployScript = pkgs.writeShellScriptBin "deploy-bun" ''
    set -euo pipefail
    if [ "$#" -lt 6 ]; then
      echo "Usage: deploy-bun <name> <git-url> <branch> <port> <subdir> <start-cmd> [domain]" >&2
      echo "Example: deploy-bun blog https://github.com/me/blog.git main 3000 . 'bun run start' blog.example.com" >&2
      exit 1
    fi
    name="$1"; shift
    repo="$1"; shift
    branch="$1"; shift
    port="$1"; shift
    subdir="$1"; shift
    startcmd="$1"; shift
    if [ "$#" -ge 1 ]; then domain="$1"; else domain=""; fi

    envdir=/etc/bun-apps
    caddydir=/etc/caddy/Caddyfile.d
    mkdir -p "$envdir" "$caddydir"

    envfile="$envdir/$name.env"
    if [ -f "$envfile" ]; then
      echo "Updating existing app env: $envfile"
    else
      echo "Creating app env: $envfile"
    fi
    cat >"$envfile" <<EOF
REPO=$(printf "%q" "$repo")
BRANCH=$(printf "%q" "$branch")
PORT=$(printf "%q" "$port")
SUBDIR=$(printf "%q" "$subdir")
START_CMD=$(printf "%q" "$startcmd")
EOF

    if [ -n "$domain" ]; then
      cat >"$caddydir/$name.caddy" <<CAD
$domain {
  reverse_proxy 127.0.0.1:$port
}
CAD
      systemctl reload caddy || true
      echo "Caddy vhost created for $domain"
    fi

    systemctl start bun-app@"$name".service
    systemctl status --no-pager bun-app@"$name".service || true
  '';

  removeScript = pkgs.writeShellScriptBin "remove-bun" ''
    set -euo pipefail
    if [ "$#" -lt 1 ]; then
      echo "Usage: remove-bun <name> [--purge]" >&2
      exit 1
    fi
    name="$1"; shift
    purge=0
    if [ "$#" -ge 1 ] && [ "$1" = "--purge" ]; then purge=1; fi

    systemctl disable --now bun-app@"$name".service || true
    rm -f "/etc/bun-apps/$name.env" || true
    rm -f "/etc/caddy/Caddyfile.d/$name.caddy" || true
    systemctl reload caddy || true
    if [ "$purge" -eq 1 ]; then
      rm -rf "/var/lib/bun-apps/$name"
      echo "Purged /var/lib/bun-apps/$name"
    fi
    echo "Removed app $name"
  '';
in
{
  options = {};

  config = {
    users.groups.bunapps = {};
    users.users.bunapps = {
      isSystemUser = true;
      group = "bunapps";
      home = "/var/lib/bun-apps";
      createHome = true;
    };

    # Ensure required tools are available to the service
    environment.systemPackages = with pkgs; [ git bun deployScript removeScript ];

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

    # Auto-start all declared envs at boot without needing systemctl enable
    systemd.services.bun-apps-autostart = {
      description = "Start all bun-app@ instances for /etc/bun-apps/*.env";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "bun-apps-autostart" ''
          set -euo pipefail
          shopt -s nullglob
          for f in /etc/bun-apps/*.env; do
            name="$(basename "$f" .env)"
            echo "Auto-starting bun-app@$name"
            systemctl start --no-block "bun-app@$name.service" || true
          done
        '';
        RemainAfterExit = true;
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
