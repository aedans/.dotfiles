{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    # nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { 
      nixpkgs,
      # nixpkgs-unstable,
      home-manager,
      ... 
  }@inputs: {
    homeConfigurations.hans = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [ ./nix/home.nix ];
    };

    nixosConfigurations.orange = nixpkgs.lib.nixosSystem {
      # specialArgs = let
      #   system = "x86_64-linux";
      # in {
      #   pkgs-unstable = import nixpkgs-unstable {
      #     inherit system;
      #     config.allowUnfree = true;
      #   };
      # };
      system = "x86_64-linux";

      modules = [
        ./config/orange.nix
        home-manager.nixosModules.home-manager {
          home-manager.useUserPackages = true;
          home-manager.users.return12 = {
            imports = [
              ./home/shared.nix
            ];
          };
        }
      ];
    };

    nixosConfigurations.framework = nixpkgs.lib.nixosSystem {
      # specialArgs = let
      #   system = "x86_64-linux";
      # in {
      #   pkgs-unstable = import nixpkgs-unstable {
      #     inherit system;
      #     config.allowUnfree = true;
      #   };
      # };
      system = "x86_64-linux";
      
      modules = [
        ./config/framework.nix
        home-manager.nixosModules.home-manager {
          home-manager.useUserPackages = true;
          home-manager.users.return12 = {
            imports = [
              ./home/shared.nix
            ];
          };
        }
      ];
    };
  };
}
