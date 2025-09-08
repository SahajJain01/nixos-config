{
  description = "NixOS configuration (flake)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "aarch64-linux";
    in {
      nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./configuration.nix
          ];
        };
      };
    };
}
