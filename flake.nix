{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    winapps = {
      url = "github:winapps-org/winapps";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { 
      nixpkgs,
      home-manager,
      winapps,
      ... 
  }@inputs: {
    nixosConfigurations.orange = nixpkgs.lib.nixosSystem rec {
      system = "x86_64-linux";

      specialArgs = {
        inherit inputs system;
      };

      modules = [
        ./config/orange.nix
        (
          {
            pkgs,
            system ? pkgs.system,
            ...
          }:
          {
            environment.systemPackages = [
              winapps.packages."${system}".winapps
            ];
          }
        )
      ];
    };

    nixosConfigurations.framework = nixpkgs.lib.nixosSystem rec {
      system = "x86_64-linux";

      specialArgs = {
        inherit inputs system;
      };

      modules = [
        ./config/framework.nix
        (
          {
            pkgs,
            system ? pkgs.system,
            ...
          }:
          {
            environment.systemPackages = [
              winapps.packages."${system}".winapps
            ];
          }
        )
      ];
    };

    nixosConfigurations.vbox = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./config/vbox.nix
      ];
    };
  };
}
