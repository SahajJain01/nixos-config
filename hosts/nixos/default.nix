{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/bun-apps.nix
  ];

  # Basic host identity and SSH
  networking.hostName = "nixos";
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
    };
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDmQSQt8pJAuVrlfPSwMpjyrwtRrZhhv/mKNaW9PYCJz4TUaOEIRLDyVrWZlOSJlcfRxnxlBSg6QXqeUphYVe6SvES+cg7NYCLPK3YjWVEGe2YI+FeMhBUJIqjTyylNY1NY3aq6Q7mrT7cT0rqLtIdTk7DiVEsrINWg/yT+CAG9KbWuk+/aNXpGdPNfMJkHzt/25wCPpoOP2ByxbKKnH6qBWpnzZn/xbhm0XIZYxqc6iklVsCFIs2E2gvH1NINniuOgUsReWCrnFigEhH8P5V90Qxwr/65ttakNSV4SEnDFEMecGk9qAlKrg+N8oLQrLh1+Bs0f5NOKLlP7m+FmR6sV imported-openssh-key"
  ];

  # Open only what’s needed; Caddy handles 80/443
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];

  # Locale / bootloader
  time.timeZone = "Asia/Kolkata";
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Flakes support
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.05";

  # Bun monorepo auto-deployer. Fill in your repo URL and optionally a webhook domain.
  # This replaces the old deploy-bun flow with a repo-driven deploy.
  services.bunMonorepo = {
    enable = true;
    repoUrl = "https://github.com/SahajJain01/bun-apps.git";
    branch = "main";
    appsDir = "apps";
    portBase = 3000;
    portRange = 1000;
    webhook = {
      enable = true;
      listenAddress = "127.0.0.1"; # keep local; expose via Caddy domain below
      port = 8787;
      path = "/sync";
      tokenFile = "/etc/bun-apps/webhook-secret";
      domain = "deploy.sahajjain.com";
    };
  };
}
