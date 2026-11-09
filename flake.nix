{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # MTGO's wine carries patches, so it has no binary cache; pinned so that
    # updating nixpkgs doesn't recompile it
    nixpkgs-wine.url = "github:NixOS/nixpkgs/cf5e76507c6e23b59f7e0ffcc7baa2a39ddd8442";
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
      nixpkgs-wine,
      stylix,
      home-manager,
      llm-agents,
      chaotic,
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
        pkgs-llm-agents = llm-agents.packages.${system};
        pkgs-wine = import nixpkgs-wine { inherit system; };
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
        pkgs-wine = import nixpkgs-wine { inherit system; };
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
