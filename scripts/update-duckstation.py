#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 ChomiamOS Project

import json
import os
import re
import subprocess
import sys
import urllib.request

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKAGE_NIX = os.path.join(REPO_ROOT, "package.nix")

def main():
    print("🦆 Vérification des nouvelles versions amont de DuckStation...")

    # 1. Résolution du commit de la release 'latest' sur GitHub
    ls_remote = subprocess.check_output([
        "git", "ls-remote", "https://github.com/stenzek/duckstation.git", "refs/tags/latest"
    ]).decode()

    latest_sha = ls_remote.split()[0] if ls_remote.strip() else None
    if not latest_sha:
        print("❌ Impossible de résoudre le commit de refs/tags/latest.")
        sys.exit(1)

    print(f"📌 Dernier commit de release amont (stenzek/duckstation) : {latest_sha}")

    # 2. Lecture du commit actuel dans package.nix
    with open(PACKAGE_NIX, "r", encoding="utf-8") as f:
        content = f.read()

    match_rev = re.search(r'rev\s*=\s*"([a-f0-9]+)";', content)
    if not match_rev:
        print("❌ Impossible de trouver 'rev' dans package.nix.")
        sys.exit(1)

    current_sha = match_rev.group(1)
    print(f"📦 Commit actuellement configuré dans package.nix : {current_sha}")

    if latest_sha == current_sha:
        print("✅ DuckStation est déjà à jour avec la dernière version amont.")
        if "GITHUB_OUTPUT" in os.environ:
            with open(os.environ["GITHUB_OUTPUT"], "a") as gh_out:
                gh_out.write("has_update=false\n")
        sys.exit(0)

    short_sha = latest_sha[:7]
    print(f"🚀 Nouvelle version détectée : {current_sha[:7]} ➔ {short_sha} !")

    # 3. Calcul du nouveau hash source via nix-prefetch-url
    print("⏳ Téléchargement et calcul de l'empreinte sha256...")
    archive_url = f"https://github.com/stenzek/duckstation/archive/{latest_sha}.tar.gz"
    b32_hash = subprocess.check_output(["nix-prefetch-url", "--unpack", archive_url]).decode().strip()
    sri_hash = subprocess.check_output(["nix", "hash", "to-sri", "--type", "sha256", b32_hash]).decode().strip()
    print(f"🔑 Empreinte SRI : {sri_hash}")

    # 4. Vérification des dépendances précompilées (duckstation/dependencies)
    prebuilt_ver_match = re.search(r'prebuiltVersion\s*=\s*"([^"]+)";', content)
    current_prebuilt_ver = prebuilt_ver_match.group(1) if prebuilt_ver_match else None

    try:
        req = urllib.request.Request(
            "https://api.github.com/repos/duckstation/dependencies/releases",
            headers={"User-Agent": "duckstation-nix-updater"}
        )
        with urllib.request.urlopen(req) as resp:
            deps_releases = json.loads(resp.read().decode())
            if isinstance(deps_releases, list) and len(deps_releases) > 0:
                latest_deps_tag = deps_releases[0].get("tag_name")
                if latest_deps_tag and latest_deps_tag != current_prebuilt_ver:
                    print(f"📦 Nouvelle version des dépendances : {current_prebuilt_ver} ➔ {latest_deps_tag}")
                    deps_url = f"https://github.com/duckstation/dependencies/releases/download/{latest_deps_tag}/deps-linux-x64.tar.xz"
                    deps_b32 = subprocess.check_output(["nix-prefetch-url", deps_url]).decode().strip()
                    deps_sri = subprocess.check_output(["nix", "hash", "to-sri", "--type", "sha256", deps_b32]).decode().strip()
                    content = re.sub(r'prebuiltVersion\s*=\s*"[^"]+";', f'prebuiltVersion = "{latest_deps_tag}";', content, count=1)
                    content = re.sub(
                        r'(prebuiltDeps\s*=\s*fetchurl\s*\{[^}]*hash\s*=\s*")[^"]+(";)',
                        rf'\g<1>{deps_sri}\g<2>',
                        content
                    )
    except Exception as e:
        print(f"⚠️ Avertissement lors de la vérification des dépendances : {e}")

    # 5. Mise à jour de package.nix
    content = re.sub(r'version\s*=\s*"[^"]+";', f'version = "{short_sha}";', content, count=1)
    content = re.sub(r'rev\s*=\s*"[^"]+";', f'rev = "{latest_sha}";', content, count=1)
    content = re.sub(r'hash\s*=\s*"sha256-[^"]+";', f'hash = "{sri_hash}";', content, count=1)

    for asset in ["cheats", "patches"]:
        try:
            asset_url = f"https://github.com/duckstation/chtdb/releases/download/latest/{asset}.zip"
            h_b32 = subprocess.check_output(["nix-prefetch-url", asset_url]).decode().strip()
            h_sri = subprocess.check_output(["nix", "hash", "to-sri", "--type", "sha256", h_b32]).decode().strip()
            pat = rf'({asset}\s*=\s*fetchurl\s*\{{[^}}]*hash\s*=\s*")[^"]+(";)'
            content = re.sub(pat, rf'\g<1>{h_sri}\g<2>', content)
        except Exception as e:
            print(f"⚠️ Avertissement pour {asset} : {e}")

    with open(PACKAGE_NIX, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"🎉 package.nix mis à jour avec succès vers {short_sha} !")

    if "GITHUB_OUTPUT" in os.environ:
        with open(os.environ["GITHUB_OUTPUT"], "a") as gh_out:
            gh_out.write("has_update=true\n")
            gh_out.write(f"new_version={short_sha}\n")
            gh_out.write(f"new_commit={latest_sha}\n")

if __name__ == "__main__":
    main()
