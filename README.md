# 🦆 DuckStation Nix Flake (ChomiamOS)

[![Build & Cachix Push](https://github.com/Chomiam/duckstation-nix/actions/workflows/build.yml/badge.svg)](https://github.com/Chomiam/duckstation-nix/actions/workflows/build.yml)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL_3.0--or--later-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Cachix Cache](https://img.shields.io/badge/Cachix-duckstation-orange.svg)](https://duckstation.cachix.org)

Paquet Nix Flake officiel pour l'émulateur PlayStation 1 (PSX) [DuckStation](https://github.com/stenzek/duckstation), compilé depuis les sources pour [ChomiamOS](https://github.com/Chomiam/nix_config_gaming) et NixOS.

---

## ✨ Caractéristiques

- ⚙️ **Compilation native depuis les sources** : Intégration LLVM/Clang et LLD avec standard C++20.
- 📦 **Précompilation et mise en cache Cachix** : Binaire précompilé et disponible immédiatement via `https://duckstation.cachix.org`.
- 🪟 **Support Wayland & X11** : Détection automatique de la session graphique et intégration des plateformes Qt6.
- 🎮 **Compatible ES-DE** : Détection et lancement immédiat par le frontend EmulationStation Desktop Edition.

---

## ⚡ Cache Binaire Cachix

Pour éviter toute recompilation locale et télécharger le binaire précompilé :

```bash
cachix use duckstation
```

Ou ajoutez directement dans la section `nixConfig` de votre `flake.nix` :

```nix
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
```

---

## 🚀 Utilisation

### Lancement direct via `nix run`
```bash
nix run github:Chomiam/duckstation-nix
```

### Intégration dans un système NixOS
Ajoutez le flake à vos entrées dans `flake.nix` :

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    duckstation.url = "github:Chomiam/duckstation-nix";
  };

  outputs = { self, nixpkgs, duckstation, ... }: {
    nixosConfigurations.chomiamos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            duckstation.packages.${pkgs.stdenv.hostPlatform.system}.duckstation
          ];
        })
      ];
    };
  };
}
```

---

## 📄 Licence et Conformité Légale (GPL-3.0)

Ce dépôt respecte scrupuleusement les exigences des licences libres et de la communauté open source :

- **Licence du dépôt** : Les fichiers de recette de compilation Nix (`package.nix`), la configuration Flake (`flake.nix`), ainsi que les scripts d'intégration de ce dépôt sont distribués sous licence libre **GNU General Public License v3.0 (GPL-3.0-or-later)**.
- **Texte officiel de la licence** : Voir le fichier [`LICENSE`](./LICENSE) inclus à la racine de ce dépôt.
- **Crédits & Code Source Upstream** :
  - L'émulateur DuckStation est développé et maintenu par **Connor McLaughlin (stenzek)** et les contributeurs de DuckStation.
  - Le code source complet de l'émulateur est accessible publiquement sur le dépôt amont officiel : [https://github.com/stenzek/duckstation](https://github.com/stenzek/duckstation).
  - Ce dépôt construit DuckStation à partir des sources officielles conformément aux instructions de compilation publiques de l'auteur amont.
