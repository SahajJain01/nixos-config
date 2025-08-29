{ config, lib, pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Convenience wrapper for rebuilding from the current directory (or a given flake path)
  environment.shellAliases = {
    nswitch = "sudo -E nixos-rebuild switch --flake .#nixos";
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "nswitch" ''
      set -euo pipefail
      flake="''${1:-.}#nixos"
      if [ "$(id -u)" -eq 0 ]; then
        exec /run/current-system/sw/bin/nixos-rebuild switch --flake "$flake"
      else
        exec sudo -E /run/current-system/sw/bin/nixos-rebuild switch --flake "$flake"
      fi
    '')
  ];
}
