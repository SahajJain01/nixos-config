{ config, lib, pkgs, ... }:
{
  # Imports
  imports = [
    ./hardware-configuration.nix
  ];

  # Nix
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-public-keys = [ "ci-deploy:VJtvUEyxn33j9CjDqp8TpWKafRabCHpPs/hMeIns3Xc=" ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Time
  time.timeZone = "Asia/Kolkata";

  # Networking
  networking.hostName = "nixos";
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 ];
    allowedTCPPortRanges = [{ from = 3000; to = 3999; }];
    allowedUDPPorts = [];
  };

  # Users
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDmQSQt8pJAuVrlfPSwMpjyrwtRrZhhv/mKNaW9PYCJz4TUaOEIRLDyVrWZlOSJlcfRxnxlBSg6QXqeUphYVe6SvES+cg7NYCLPK3YjWVEGe2YI+FeMhBUJIqjTyylNY1NY3aq6Q7mrT7cT0rqLtIdTk7DiVEsrINWg/yT+CAG9KbWuk+/aNXpGdPNfMJkHzt/25wCPpoOP2ByxbKKnH6qBWpnzZn/xbhm0XIZYxqc6iklVsCFIs2E2gvH1NINniuOgUsReWCrnFigEhH8P5V90Qxwr/65ttakNSV4SEnDFEMecGk9qAlKrg+N8oLQrLh1+Bs0f5NOKLlP7m+FmR6sV imported-openssh-key"
  ];
  users.users.github = {
    isNormalUser = true;
    description = "Deployment user for GitHub Actions";
    home = "/home/github";
    createHome = true;
    linger = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDmQSQt8pJAuVrlfPSwMpjyrwtRrZhhv/mKNaW9PYCJz4TUaOEIRLDyVrWZlOSJlcfRxnxlBSg6QXqeUphYVe6SvES+cg7NYCLPK3YjWVEGe2YI+FeMhBUJIqjTyylNY1NY3aq6Q7mrT7cT0rqLtIdTk7DiVEsrINWg/yT+CAG9KbWuk+/aNXpGdPNfMJkHzt/25wCPpoOP2ByxbKKnH6qBWpnzZn/xbhm0XIZYxqc6iklVsCFIs2E2gvH1NINniuOgUsReWCrnFigEhH8P5V90Qxwr/65ttakNSV4SEnDFEMecGk9qAlKrg+N8oLQrLh1+Bs0f5NOKLlP7m+FmR6sV imported-openssh-key"
    ];
  };
  systemd.tmpfiles.rules = [
    "d /srv/apps 0755 github github - -"
    "d /srv/caddy 0755 root root - -"
    "d /srv/caddy/conf.d 0750 github caddy - -"
  ];

  # Services
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
  };

  # Caddy reverse proxy (HTTPS via Let's Encrypt)
  services.caddy = {
    enable = true;
    # Set your email for ACME/Let's Encrypt registration
    email = "jainsahaj@gmail.com";
    # Import per-app vhost snippets from a writeable dir
    extraConfig = ''
      import /srv/caddy/conf.d/*.caddy
    '';
    # Optional: use LE staging while testing to avoid rate limits
    # acmeCA = "https://acme-staging-v02.api.letsencrypt.org/directory";
  };

  # Directory for dynamic Caddy vhost configs set above

  # Environment
  environment.systemPackages = with pkgs; [
    git
  ];
  environment.shellAliases = {
    nswitch = "nixos-rebuild switch";
  };

  # Do not change this value unless you know what you are doing.
  system.stateVersion = "25.05";
}
