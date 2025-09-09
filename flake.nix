{
  description = "NixOS Homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs = { self, nixpkgs, deploy-rs }:
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

      deploy = {
        nodes = {
          nixos = {
            hostname = "nixos";
            profiles.system = {
              user = "deployer";
              path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.nixos;
            };
          };
        };
      };

      apps.${system}.deploy = {
        type = "app";
        program = "${deploy-rs.packages.${system}.deploy-rs}/bin/deploy";
      };

      packages.${system}.deploy = deploy-rs.packages.${system}.deploy-rs;
      checks.${system}.deploy = deploy-rs.lib.${system}.deployChecks self.deploy;
    };
}
