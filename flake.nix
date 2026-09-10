{
  description = "Paquet Nix officiel pour l'émulateur PlayStation 1 DuckStation (ChomiamOS)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in
      {
        packages = rec {
          duckstation = pkgs.callPackage ./package.nix { };
          default = duckstation;
        };

        apps = rec {
          duckstation = flake-utils.lib.mkApp { drv = self.packages.${system}.duckstation; };
          default = duckstation;
        };
      }
    );

  nixConfig = {
    extra-substituters = [
      "https://duckstation.cachix.org"
      "https://cache.nixos.org"
    ];
    extra-trusted-public-keys = [
      "duckstation.cachix.org-1:tNC6UMoM5ZojxBRDdPNHC3xBlk7hnClCtsGsho3YiY4="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };
}
