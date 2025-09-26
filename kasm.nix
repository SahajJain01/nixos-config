{ config, lib, pkgs, ... }:

let
  cfg = config.services.kasm;

  releaseName = "kasm_release_${cfg.version}.${cfg.buildId}";
  kasmArchive = pkgs.fetchurl {
    url = "https://kasm-static-content.s3.amazonaws.com/${releaseName}.tar.gz";
    sha256 = cfg.sha256;
  };

  kasmUnpacked = pkgs.runCommand "kasm-release-${cfg.version}" { } ''
    mkdir -p work
    tar -xzf ${kasmArchive} -C work
    substituteInPlace work/kasm_release/docker/docker-compose-all.yaml \
      --replace "POSTGRES_PASSWORD: changeme" "POSTGRES_PASSWORD: \\\${POSTGRES_PASSWORD}" \
      --replace "REDIS_PASSWORD: changeme" "REDIS_PASSWORD: \\\${REDIS_PASSWORD}" \
      --replace "\"443:443\"" "\"${cfg.publicPort}:${cfg.containerHttpsPort}\"" \
      --replace "\"3389:3389\"" "\"${cfg.rdpPort}:${cfg.containerRdpPort}\""
    mkdir -p $out
    cp -a work/kasm_release/. $out/
  '';

  dockerBin = "${pkgs.docker}/bin/docker";
  composeBin = "${pkgs.docker-compose}/bin/docker-compose";
  bashBin = "${pkgs.bash}/bin/bash";

  ensureCommand = cmd: "${bashBin} -c ${lib.escapeShellArg cmd}";
  networkEnsure = name: ensureCommand "${dockerBin} network inspect ${name} >/dev/null 2>&1 || ${dockerBin} network create ${name}";
  volumeEnsure = name: ensureCommand "${dockerBin} volume inspect ${name} >/dev/null 2>&1 || ${dockerBin} volume create ${name}";

in {
  options.services.kasm = {
    enable = lib.mkEnableOption "Kasm Workspaces multi-container stack";

    version = lib.mkOption {
      type = lib.types.str;
      default = "1.16.0";
      description = "Upstream Kasm Workspaces version.";
    };

    buildId = lib.mkOption {
      type = lib.types.str;
      default = "a1d5b7";
      description = "Build identifier component used in the release archive name.";
    };

    sha256 = lib.mkOption {
      type = lib.types.str;
      default = "1iq7g3dynjb2g9bpq21ci2nkq7yyp0yg9nr46262fn2rlx1fgnyr";
      description = "Nix base32 hash for the release archive.";
    };

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/kasm";
      description = "Writable directory to unpack and persist the Kasm release.";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "Numeric UID provided as KASM_UID to containers.";
    };

    gid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "Numeric GID provided as KASM_GID to containers.";
    };

    postgresPassword = lib.mkOption {
      type = lib.types.str;
      default = "changeme";
      description = "Password for the embedded PostgreSQL instance. Override in production.";
    };

    redisPassword = lib.mkOption {
      type = lib.types.str;
      default = "changeme";
      description = "Password for the embedded Redis instance. Override in production.";
    };

    publicPort = lib.mkOption {
      type = lib.types.port;
      default = 443;
      description = "Host port exposed for the HTTPS proxy.";
    };

    rdpPort = lib.mkOption {
      type = lib.types.port;
      default = 3389;
      description = "Host port exposed for the RDP gateway.";
    };

    containerHttpsPort = lib.mkOption {
      type = lib.types.port;
      default = 443;
      readOnly = true;
      description = "Internal HTTPS port for the proxy container.";
    };

    containerRdpPort = lib.mkOption {
      type = lib.types.port;
      default = 3389;
      readOnly = true;
      description = "Internal RDP port for the gateway container.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.docker.enable;
        message = "services.kasm requires virtualisation.docker.enable = true";
      }
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0755 root root - -"
      "d ${cfg.stateDir}/secrets 0700 root root - -"
    ];

    system.activationScripts.kasm-release = lib.stringAfter [ "var" ] ''
      set -euo pipefail
      dest="${cfg.stateDir}/${cfg.version}"
      secrets="${cfg.stateDir}/secrets"

      install -d -m 0755 "${cfg.stateDir}"
      if [ ! -d "$dest" ] || [ ! -f "$dest/.kasm-build" ] || [ "$(cat "$dest/.kasm-build")" != "${cfg.buildId}" ]; then
        rm -rf "$dest"
        mkdir -p "$dest"
        cp -a ${kasmUnpacked}/. "$dest/"
        echo "${cfg.buildId}" > "$dest/.kasm-build"
      fi

      install -d -m 0755 "$dest/log" "$dest/tmp"
      install -d -m 0755 "$dest/log/nginx" "$dest/log/postgres" "$dest/log/logrotate"
      install -d -m 0755 "$dest/tmp/api" "$dest/tmp/manager" "$dest/tmp/guac" "$dest/tmp/rdpgw" "$dest/tmp/rdpgw/tmp" "$dest/tmp/rdpgw/var"

      install -d -m 0700 "$secrets"
      if [ ! -f "$secrets/postgres_password" ]; then
        printf '%s\n' '${cfg.postgresPassword}' > "$secrets/postgres_password"
      fi
      if [ ! -f "$secrets/redis_password" ]; then
        printf '%s\n' '${cfg.redisPassword}' > "$secrets/redis_password"
      fi
      chmod 600 "$secrets/postgres_password" "$secrets/redis_password"

      cat > "$dest/docker/.env" <<__KASM_ENV__
KASM_UID=${toString cfg.uid}
KASM_GID=${toString cfg.gid}
POSTGRES_PASSWORD=$(cat "$secrets/postgres_password")
REDIS_PASSWORD=$(cat "$secrets/redis_password")
KASM_PROXY_PORT=${toString cfg.publicPort}
KASM_RDP_PORT=${toString cfg.rdpPort}
__KASM_ENV__
      chmod 600 "$dest/docker/.env"

      install -d -m 0755 /opt/kasm
      ln -sfn "$dest" /opt/kasm/${cfg.version}
      ln -sfn "$dest" /opt/kasm/current
    '';

    systemd.services.kasm-workspaces = {
      description = "Kasm Workspaces stack";
      after = [ "docker.service" "docker.socket" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.docker pkgs.docker-compose pkgs.bash pkgs.coreutils pkgs.gnugrep pkgs.util-linux ];
      serviceConfig = {
        WorkingDirectory = "${cfg.stateDir}/${cfg.version}/docker";
        Environment = "COMPOSE_PROJECT_NAME=kasm";
        ExecStartPre = [
          (networkEnsure "kasm_default_network")
          (networkEnsure "kasm_sidecar_network")
          (volumeEnsure "kasm_db_${cfg.version}")
        ];
        ExecStart = "${composeBin} --no-ansi --file docker-compose-all.yaml up";
        ExecStop = "${composeBin} --no-ansi --file docker-compose-all.yaml down";
        Restart = "always";
        RestartSec = 5;
        TimeoutStopSec = 180;
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkAfter [ cfg.publicPort cfg.rdpPort ];
  };
}
