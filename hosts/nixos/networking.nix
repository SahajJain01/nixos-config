{ config, lib, pkgs, ... }:

{
  networking.hostName = "nixos";

  # Open only what's needed; Caddy handles 80/443
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
  };
}

