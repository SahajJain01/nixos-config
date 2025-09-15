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
        static_configs = [
          { targets = [ "127.0.0.1:3000" ]; labels = { app = "bun"; service = "calendar"; }; }
          { targets = [ "127.0.0.1:3001" ]; labels = { app = "bun"; service = "pizza";    }; }
          { targets = [ "127.0.0.1:3002" ]; labels = { app = "bun"; service = "lingscript";}; }
        ];
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
    # Make dashboards viewable publicly (or via anonymous viewer)
    # Flattened INI keys are required for multi-level sections like auth.anonymous
    settings = {
      "security.allow_embedding" = true;
      "auth.anonymous.enabled" = true;
      "auth.anonymous.org_role" = "Viewer";
      "public_dashboards.enabled" = true;
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
      dashboards.settings.providers = [
        {
          name = "bun-overview";
          orgId = 1;
          folder = "";
          type = "file";
          disableDeletion = false;
          editable = true;
          options = { path = "/etc/grafana-dashboards"; };
        }
      ];
    };
  };

  # Ship dashboard JSONs to a known path for provisioning
  environment.etc."grafana-dashboards/bun-overview.json".text = builtins.readFile ./dashboards/bun-overview.json;
}
