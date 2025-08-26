{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  ############################
  # USERS
  ############################
  users.users.spawnhouse = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [ tree ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDmQSQt8pJAuVrlfPSwMpjyrwtRrZhhv/mKNaW9PYCJz4TUaOEIRLDyVrWZlOSJlcfRxnxlBSg6QXqeUphYVe6SvES+cg7NYCLPK3YjWVEGe2YI+FeMhBUJIqjTyylNY1NY3aq6Q7mrT7cT0rqLtIdTk7DiVEsrINWg/yT+CAG9KbWuk+/aNXpGdPNfMJkHzt/25wCPpoOP2ByxbKKnH6qBWpnzZn/xbhm0XIZYxqc6iklVsCFIs2E2gvH1NINniuOgUsReWCrnFigEhH8P5V90Qxwr/65ttakNSV4SEnDFEMecGk9qAlKrg+N8oLQrLh1+Bs0f5NOKLlP7m+FmR6sV imported-openssh-key"
    ];
    hashedPassword = "!";
  };

  security.sudo.extraRules = [{
    users = [ "spawnhouse" ];
    commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
  }];

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDmQSQt8pJAuVrlfPSwMpjyrwtRrZhhv/mKNaW9PYCJz4TUaOEIRLDyVrWZlOSJlcfRxnxlBSg6QXqeUphYVe6SvES+cg7NYCLPK3YjWVEGe2YI+FeMhBUJIqjTyylNY1NY3aq6Q7mrT7cT0rqLtIdTk7DiVEsrINWg/yT+CAG9KbWuk+/aNXpGdPNfMJkHzt/25wCPpoOP2ByxbKKnH6qBWpnzZn/xbhm0XIZYxqc6iklVsCFIs2E2gvH1NINniuOgUsReWCrnFigEhH8P5V90Qxwr/65ttakNSV4SEnDFEMecGk9qAlKrg+N8oLQrLh1+Bs0f5NOKLlP7m+FmR6sV imported-openssh-key"
  ];

  ############################
  # PACKAGES / TOOLS
  ############################
  environment.systemPackages = with pkgs; [
    wget git unzip lsof
    curl htop
    whois # mkpasswd for bcrypt
  ];
  nixpkgs.config.allowUnfree = true;

  ############################
  # NETWORK / FIREWALL / SSH
  ############################
  networking.hostName = "nixos";
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 443 8443 ]; # 22 for SSH, 8443 for code-server, 443 if you later reverse-proxy
    allowedUDPPorts = [ ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
    };
  };

  ############################
  # DEV EXPERIENCE
  ############################
  services.code-server = {
    enable = true;
    user = "spawnhouse";
    host = "0.0.0.0";
    port = 8443;
    auth = "password";
    # Generate with: mkpasswd -m bcrypt
    hashedPassword = "$2b$05$ynEQCbS4oBnoUNW.sCCcxuYKJe8Q8NmaT.d9sEI4xzQS6Wq/PFlDG";
    # no extensions field here — code-server doesn’t support it in the module
    # You can still install extensions via UI or CLI (below).
  };

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  ############################
  # SHELL ALIASES
  ############################
  environment.shellAliases = {
    nswitch = "sudo nixos-rebuild switch";
    nconfig = "sudo nano /etc/nixos/configuration.nix";
  };

  ############################
  # LOCALE / BOOT
  ############################
  time.timeZone = "Asia/Kolkata";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  ############################
  # NIX SETTINGS (flakes support)
  ############################
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      "https://cache.nixos.org"
      "https://cache.nix-community.org"
      "https://cache.garnix.io"
    ];
    trusted-public-keys = [
      "cache.nix-community.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2LJZ7Y2l3k="
    ];
  };

  system.stateVersion = "25.05";
}
