{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { 
      nixpkgs,
      home-manager,
      ... 
  }@inputs: {
    # home-manager.sharedModules = [ inputs.plasma-manager.homeManagerModules.plasma-manager ];

    nixosConfigurations.orange = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./config/orange.nix
      ];
    };

    nixosConfigurations.framework = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./config/framework.nix
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
