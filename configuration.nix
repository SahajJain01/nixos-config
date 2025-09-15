{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./firewall.nix
    ./containers.nix
    ./caddy.nix
    ./monitoring.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "deployer" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Asia/Kolkata";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
  };

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune.enable = true;
  };

  networking.hostName = "nixos";

  users.users.deployer = {
    isNormalUser = true;
    description = "Deploy user";
    createHome = true;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDmQSQt8pJAuVrlfPSwMpjyrwtRrZhhv/mKNaW9PYCJz4TUaOEIRLDyVrWZlOSJlcfRxnxlBSg6QXqeUphYVe6SvES+cg7NYCLPK3YjWVEGe2YI+FeMhBUJIqjTyylNY1NY3aq6Q7mrT7cT0rqLtIdTk7DiVEsrINWg/yT+CAG9KbWuk+/aNXpGdPNfMJkHzt/25wCPpoOP2ByxbKKnH6qBWpnzZn/xbhm0XIZYxqc6iklVsCFIs2E2gvH1NINniuOgUsReWCrnFigEhH8P5V90Qxwr/65ttakNSV4SEnDFEMecGk9qAlKrg+N8oLQrLh1+Bs0f5NOKLlP7m+FmR6sV imported-openssh-key"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDmQSQt8pJAuVrlfPSwMpjyrwtRrZhhv/mKNaW9PYCJz4TUaOEIRLDyVrWZlOSJlcfRxnxlBSg6QXqeUphYVe6SvES+cg7NYCLPK3YjWVEGe2YI+FeMhBUJIqjTyylNY1NY3aq6Q7mrT7cT0rqLtIdTk7DiVEsrINWg/yT+CAG9KbWuk+/aNXpGdPNfMJkHzt/25wCPpoOP2ByxbKKnH6qBWpnzZn/xbhm0XIZYxqc6iklVsCFIs2E2gvH1NINniuOgUsReWCrnFigEhH8P5V90Qxwr/65ttakNSV4SEnDFEMecGk9qAlKrg+N8oLQrLh1+Bs0f5NOKLlP7m+FmR6sV imported-openssh-key"
  ];

  environment.shellAliases = {
    nswitch = "nixos-rebuild switch";
  };

  environment.systemPackages = with pkgs; [
    git
  ];

  system.stateVersion = "25.05";
}
