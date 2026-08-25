{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      # llm-agents pins nixpkgs (25.11-era), which is required for its
      # packages to evaluate (e.g. pnpm_11); following our nixpkgs here breaks it.
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = { 
      nixpkgs,
      nixpkgs-unstable,
      stylix,
      home-manager,
      llm-agents,
      chaotic,
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
        };
        pkgs-llm-agents = llm-agents.packages.${system};
      };

      system = "x86_64-linux";

      modules = [
        stylix.nixosModules.stylix
        chaotic.nixosModules.default
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
        };
        pkgs-llm-agents = llm-agents.packages.${system};
      };

      system = "x86_64-linux";
      
      modules = [
        stylix.nixosModules.stylix
        chaotic.nixosModules.default
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
