{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { 
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      ... 
  }@inputs: {
    nixosConfigurations.orange = nixpkgs.lib.nixosSystem {
      specialArgs = let
        system = "x86_64-linux";
      in {
        pkgs-unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      };
      
      modules = [
        ./config/orange.nix
      ];
    };

    nixosConfigurations.framework = nixpkgs.lib.nixosSystem {
      specialArgs = let
        system = "x86_64-linux";
      in {
        pkgs-unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      };
      
      modules = [
        ./config/framework.nix
      ];
    };

    nixosConfigurations.vbox = nixpkgs.lib.nixosSystem {
      specialArgs = let
        system = "x86_64-linux";
      in {
        pkgs-unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      };
      
      modules = [
        ./config/vbox.nix
      ];
    };
  };
}
