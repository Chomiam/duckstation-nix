# 🦆 DuckStation Nix Flake

Paquet Nix autonome pour l'émulateur PlayStation 1 [DuckStation](https://github.com/stenzek/duckstation) avec compilation C++20 et intégration Cachix pour [ChomiamOS](https://github.com/Chomiam/nix_config_gaming).

## ⚡ Cache binaire Cachix

```bash
cachix use duckstation
```

Ou ajoutez directement dans votre `flake.nix` :

```nix
nixConfig = {
  extra-substituters = [ "https://duckstation.cachix.org" ];
  extra-trusted-public-keys = [ "duckstation.cachix.org-1:tNC6UMoM5ZojxBRDdPNHC3xBlk7hnClCtsGsho3YiY4=" ];
};
```

## 🚀 Utilisation directe

```bash
nix run github:Chomiam/duckstation-nix
```
