{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDmQSQt8pJAuVrlfPSwMpjyrwtRrZhhv/mKNaW9PYCJz4TUaOEIRLDyVrWZlOSJlcfRxnxlBSg6QXqeUphYVe6SvES+cg7NYCLPK3YjWVEGe2YI+FeMhBUJIqjTyylNY1NY3aq6Q7mrT7cT0rqLtIdTk7DiVEsrINWg/yT+CAG9KbWuk+/aNXpGdPNfMJkHzt/25wCPpoOP2ByxbKKnH6qBWpnzZn/xbhm0XIZYxqc6iklVsCFIs2E2gvH1NINniuOgUsReWCrnFigEhH8P5V90Qxwr/65ttakNSV4SEnDFEMecGk9qAlKrg+N8oLQrLh1+Bs0f5NOKLlP7m+FmR6sV imported-openssh-key"
  ];

  environment.systemPackages = with pkgs; [
    git
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

  environment.shellAliases = {
    nswitch = "nixos-rebuild switch";
    nconfig = "nano /etc/nixos/configuration.nix";
  };

  networking.hostName = "nixos";

  time.timeZone = "Asia/Ho_Chi_Minh";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "25.05";
}
