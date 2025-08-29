{ config, lib, pkgs, ... }:

{
  # Import the reusable Bun/Caddy deploy module
  imports = [ ../../../modules/bun-apps.nix ];

  # Monorepo auto-deployer configuration
  services.bunMonorepo = {
    enable = true;
    repoUrl = "https://github.com/SahajJain01/bun-apps.git";
    branch = "main";
    appsDir = "apps";
    portBase = 3000;
    portRange = 1000;
    webhook = {
      enable = true;
      listenAddress = "127.0.0.1"; # keep local; exposed via Caddy domain below
      port = 8787;
      path = "/sync";
      tokenFile = "/etc/bun-apps/webhook-secret";
      domain = "deploy.sahajjain.com";
    };
  };
}

