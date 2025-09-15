{ config, lib, pkgs, ... }:

{
  # Expose Docker engine metrics for Prometheus on localhost
  virtualisation.docker.daemon.settings = {
    "metrics-addr" = "127.0.0.1:9323";
  };

  # Node exporter for host metrics
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9100;
  };

  # Prometheus server
  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9090;
    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };
    scrapeConfigs = [
      # Host metrics
      {
        job_name = "node";
        static_configs = [{ targets = [ "127.0.0.1:9100" ]; }];
      }

      # Docker engine metrics (not per-container; see cAdvisor below)
      {
        job_name = "docker-engine";
        static_configs = [{ targets = [ "127.0.0.1:9323" ]; }];
      }

      # cAdvisor per-container metrics
      {
        job_name = "cadvisor";
        static_configs = [{ targets = [ "127.0.0.1:8080" ]; }];
      }

      # Bun apps (expect /metrics inside each container)
      {
        job_name = "bun-apps";
        metrics_path = "/metrics";
        static_configs = [{
          targets = [
            "127.0.0.1:3000" # calendar
            "127.0.0.1:3001" # pizza
            "127.0.0.1:3002" # lingscript
          ];
          labels = { app = "bun"; };
        }];
      }
    ];
  };

  # Grafana with Prometheus datasource
  services.grafana = {
    enable = true;
    settings.server = {
      http_addr = "127.0.0.1";
      http_port = 3030; # Avoid clash with your apps using 3000-3002
      domain = "grafana.sahajjain.com";
      root_url = "https://grafana.sahajjain.com/";
    };
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://127.0.0.1:9090";
          isDefault = true;
          access = "proxy";
        }
      ];
    };
  };
}
