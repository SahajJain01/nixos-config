{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  users.users.spawnhouse = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
    ];
    packages = with pkgs; [
      tree
    ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDmQSQt8pJAuVrlfPSwMpjyrwtRrZhhv/mKNaW9PYCJz4TUaOEIRLDyVrWZlOSJlcfRxnxlBSg6QXqeUphYVe6SvES+cg7NYCLPK3YjWVEGe2YI+FeMhBUJIqjTyylNY1NY3aq6Q7mrT7cT0rqLtIdTk7DiVEsrINWg/yT+CAG9KbWuk+/aNXpGdPNfMJkHzt/25wCPpoOP2ByxbKKnH6qBWpnzZn/xbhm0XIZYxqc6iklVsCFIs2E2gvH1NINniuOgUsReWCrnFigEhH8P5V90Qxwr/65ttakNSV4SEnDFEMecGk9qAlKrg+N8oLQrLh1+Bs0f5NOKLlP7m+FmR6sV imported-openssh-key" # Replace with your actual public key
    ];
    hashedPassword = "!";
  };

  security.sudo.extraRules = [{
    users = [ "spawnhouse" ];
    commands = [
      { command = "ALL"; options = [ "NOPASSWD" ]; }
    ];
  }];

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDmQSQt8pJAuVrlfPSwMpjyrwtRrZhhv/mKNaW9PYCJz4TUaOEIRLDyVrWZlOSJlcfRxnxlBSg6QXqeUphYVe6SvES+cg7NYCLPK3YjWVEGe2YI+FeMhBUJIqjTyylNY1NY3aq6Q7mrT7cT0rqLtIdTk7DiVEsrINWg/yT+CAG9KbWuk+/aNXpGdPNfMJkHzt/25wCPpoOP2ByxbKKnH6qBWpnzZn/xbhm0XIZYxqc6iklVsCFIs2E2gvH1NINniuOgUsReWCrnFigEhH8P5V90Qxwr/65ttakNSV4SEnDFEMecGk9qAlKrg+N8oLQrLh1+Bs0f5NOKLlP7m+FmR6sV imported-openssh-key"
  ];

  environment.systemPackages = with pkgs; [
    wget
    git
    unzip
    lsof
  ];

  nixpkgs.config.allowUnfree = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 443 ];
    allowedUDPPorts = [];
  };

  services.openssh = {
  enable = true;
  settings = {
      PasswordAuthentication = false;
    };
  };

  virtualisation.docker = {
    enable = true;
    rootless.enable = true;
  };

  environment.shellAliases = {
    nswitch = "sudo nixos-rebuild switch";
    nconfig = "sudo nano /etc/nixos/configuration.nix";
  };

  networking.hostName = "nixos";

  time.timeZone = "Asia/Kolkata";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "25.05";
}
