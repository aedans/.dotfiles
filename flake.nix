{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    stylix = {
      url = "github:nix-community/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-llmster.url = "github:mirkolenz/nixpkgs/llmster";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { 
      nixpkgs,
      nixpkgs-unstable,
      stylix,
      nixpkgs-llmster,
      home-manager,
      ...
  }@inputs: {
    homeConfigurations.hans = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [ ./nix/home.nix ];
    };

    nixosConfigurations.orange = nixpkgs.lib.nixosSystem {
      specialArgs = let
        system = "x86_64-linux";
      in {
        pkgs-unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            (final: prev: {
              lmstudio = prev.lmstudio.override {
                version = "0.4.11-1";
                url = "https://installers.lmstudio.ai/linux/x64/0.4.11-1/LM-Studio-0.4.11-1-x64.AppImage";
                hash = "sha256-l/WVuU+1muv2HOnOHy2h6/FXibiZpj3nMzGoLFTqZFc=";
              };
            })
          ];
        };
        pkgs-llmster = import nixpkgs-llmster {
          inherit system;
          config.allowUnfree = true;
        };
      };

      system = "x86_64-linux";

      modules = [
        stylix.nixosModules.stylix
        ./config/orange.nix
        home-manager.nixosModules.home-manager {
          home-manager.useUserPackages = true;
          home-manager.users.hans = {
            imports = [ ./home/shared.nix ];
          };
        }
      ];
    };

    nixosConfigurations.framework = nixpkgs.lib.nixosSystem {
      specialArgs = let
        system = "x86_64-linux";
      in {
        pkgs-unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            (final: prev: {
              lmstudio = prev.lmstudio.override {
                version = "0.4.11-1";
                url = "https://installers.lmstudio.ai/linux/x64/0.4.11-1/LM-Studio-0.4.11-1-x64.AppImage";
                hash = "sha256-l/WVuU+1muv2HOnOHy2h6/FXibiZpj3nMzGoLFTqZFc=";
              };
            })
          ];
        };
        pkgs-llmster = import nixpkgs-llmster {
          inherit system;
          config.allowUnfree = true;
        };
      };

      system = "x86_64-linux";
      
      modules = [
        stylix.nixosModules.stylix
        ./config/framework.nix
        home-manager.nixosModules.home-manager {
          home-manager.useUserPackages = true;
          home-manager.users.hans = {
            imports = [ ./home/shared.nix ];
          };
        }
      ];
    };
  };
}
