{ config, lib, pkgs, ... }:

{
  virtualisation.oci-containers = {
    backend = "docker";

    containers = {
      # Example container: simple nginx serving on port 8080
      # nginx = {
      #   image = "nginx:1.27";
      #   ports = [ "8080:80" ];
      #   # For persistence, mount a host directory:
      #   # volumes = [ "/var/lib/nginx:/usr/share/nginx/html:ro" ];
      #   # environment = { NGINX_ENTRYPOINT_QUIET_LOGS = "1"; };
      #   # extraOptions = [ "--pull=always" ];
      #   # restartPolicy = "always"; # defaults to unless-stopped
      # };

      # Example container: PostgreSQL (store data on host)
      # postgres = {
      #   image = "postgres:16";
      #   ports = [ "5432:5432" ];
      #   environment = {
      #     POSTGRES_USER = "postgres";
      #     POSTGRES_PASSWORD = "change-me"; # Prefer environmentFiles for secrets
      #   };
      #   volumes = [ "/var/lib/postgres:/var/lib/postgresql/data" ];
      #   # environmentFiles = [ "/run/keys/postgres.env" ];
      #   # extraOptions = [ "--pull=always" ];
      # };

      calendar = {
        image = "ghcr.io/sahajjain01/fixed-calendar:latest;";
        extraOptions = [ "--pull=always" ];
        ports = [ "3000:3000" ];
      };

      pizza = {
        image = "ghcr.io/sahajjain01/pizza-calc:latest;";
        extraOptions = [ "--pull=always" ];
        ports = [ "3001:3000" ];
      };

      lingscript = {
        image = "ghcr.io/sahajjain01/ling-script:latest;";
        extraOptions = [ "--pull=always" ];
        ports = [ "3002:3000" ];
      };

      # cAdvisor for per-container metrics (scraped by Prometheus)
      cadvisor = {
        image = "gcr.io/cadvisor/cadvisor:latest";
        extraOptions = [
          "--pull=always"
          "--privileged"
          "--device=/dev/kmsg"
        ];
        ports = [ "127.0.0.1:8080:8080" ];
        volumes = [
          "/:/rootfs:ro"
          "/var/run:/var/run:rw"
          "/sys:/sys:ro"
          "/var/lib/docker/:/var/lib/docker:ro"
          "/dev/disk/:/dev/disk:ro"
          "/sys/fs/cgroup:/sys/fs/cgroup:ro"
        ];
      };
    };
  };
}
