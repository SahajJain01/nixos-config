{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    # Host modules
    ./networking.nix
    ./ssh.nix
    ./locale.nix
    ./boot.nix
    ./nix.nix

    # Services
    ./services/bun-monorepo.nix
  ];

  system.stateVersion = "25.05";
}

