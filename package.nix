# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 ChomiamOS Project

{ lib
, llvmPackages
, gcc
, fetchFromGitHub
, fetchurl
, cmake
, ninja
, pkg-config
, patchelf
, git
, kdePackages
, curl
, glib
, pcre2
, zstd
, zlib
, fontconfig
, dbus
, libva
, libX11
, libXrandr
, libXext
, libXcursor
, libXi
, libXinerama
, libXxf86vm
, libxcb
, libxcb-util
, libxcb-image
, libxcb-keysyms
, libxcb-render-util
, libxcb-wm
, libxcb-cursor
, wayland
, wayland-protocols
, libxkbcommon
, vulkan-loader
, vulkan-headers
, libGL
, libdrm
, alsa-lib
, pipewire
, libpulseaudio
, libevdev
, systemd
, libdecor
, makeWrapper
, autoPatchelfHook
}:

let
  stdenv = llvmPackages.stdenv;
  version = "3b30876";
  prebuiltVersion = "release-20260906";

  src = fetchFromGitHub {
    owner = "stenzek";
    repo = "duckstation";
    rev = "3b30876e92f28faeaba06bcfa562939c7107961e";
    hash = "sha256-/+DlPeNEwIrjph9Nur3c/n655n/ctWRB49ckg50dW/s=";
  };

  prebuiltDeps = fetchurl {
    url = "https://github.com/duckstation/dependencies/releases/download/${prebuiltVersion}/deps-linux-x64.tar.xz";
    hash = "sha256-oXLkrGf26ojpQJNqIrRhQD0vKUSY0OCZyuQdd32FegY=";
  };

  cheats = fetchurl {
    url = "https://github.com/duckstation/chtdb/releases/download/latest/cheats.zip";
    hash = "sha256-TR+lIN5dZWqjwIyL0RBpkeDhd0+yFB/cjsSf8xGfbEI=";
  };

  patches = fetchurl {
    url = "https://github.com/duckstation/chtdb/releases/download/latest/patches.zip";
    hash = "sha256-V3Si+2kcZyeuACPh1GD0Ekedt9+S4kcZPBPwd3NMbi0=";
  };

  libPath = lib.makeLibraryPath [
    gcc.cc.lib
    glib
    pcre2.out
    zstd
    zlib
    fontconfig
    dbus
    libva
    wayland          # libwayland-egl.so.1 (dlopen par DuckStation)
    libxkbcommon     # libxkbcommon.so.0 (dlopen par DuckStation)
    libGL            # libGLX.so.0, libOpenGL.so.0 (dlopen par DuckStation)
    alsa-lib         # libasound.so.2 (dlopen par DuckStation)
    libpulseaudio    # libpulse.so.0 (dlopen par DuckStation)
    vulkan-loader    # libvulkan.so (dlopen par DuckStation)
    libdrm           # libdrm (EGL/DRM backend)
    curl             # libcurl.so.4 (dlopen par DuckStation)
  ];

in
stdenv.mkDerivation rec {
  pname = "duckstation";
  inherit version src;

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    patchelf
    git
    kdePackages.extra-cmake-modules
    llvmPackages.lld
    makeWrapper
    autoPatchelfHook
  ];

  buildInputs = [
    curl
    gcc.cc.lib
    glib
    pcre2.out
    zstd
    zlib
    fontconfig
    dbus
    libva
    libX11
    libXrandr
    libXext
    libXcursor
    libXi
    libXinerama
    libXxf86vm
    libxcb
    libxcb-util
    libxcb-image
    libxcb-keysyms
    libxcb-render-util
    libxcb-wm
    libxcb-cursor
    wayland
    wayland-protocols
    libxkbcommon
    vulkan-loader
    vulkan-headers
    libGL
    libdrm
    alsa-lib
    pipewire
    libpulseaudio
    libevdev
    systemd
    libdecor
  ];

  autoPatchelfIgnoreMissingDeps = true;

  postUnpack = ''
    mkdir -p $sourceRoot/dep/prebuilt/linux-x64
    tar -xf ${prebuiltDeps} -C $sourceRoot/dep/prebuilt
    cp ${cheats} $sourceRoot/data/resources/cheats.zip
    cp ${patches} $sourceRoot/data/resources/patches.zip
    chmod -R u+w $sourceRoot/dep/prebuilt

    # Neutralisation du contrôle d'environnement hostile
    sed -i 's/message(FATAL_ERROR "Unsupported environment.")/message(STATUS "Building on NixOS")/g' $sourceRoot/CMakeModules/DuckStationBuildSummary.cmake

    # Désactivation du popup d'avertissement LD_LIBRARY_PATH
    sed -i '/void QtHost::WarnAboutLDLibraryPath()/{n;s/{/{\n  return;/}' $sourceRoot/src/duckstation-qt/qthost.cpp

    # Marquage du build comme release officielle (fournit src/scmversion/tag.h comme dans l'amont)
    mkdir -p $sourceRoot/src/scmversion
    cat << 'TAG_EOF' > $sourceRoot/src/scmversion/tag.h
#pragma once
#define UPDATER_RELEASE_CHANNEL "latest"
#define UPDATER_RELEASE_IS_OFFICIAL 1
TAG_EOF

    # Désactivation du popup d'avertissement 'Unofficial Build Warning'
    sed -i '/void AutoUpdaterDialog::warnAboutUnofficialBuild()/{n;s/{/{\n  return;/}' $sourceRoot/src/duckstation-qt/autoupdaterdialog.cpp
    sed -i 's/AutoUpdaterDialog::warnAboutUnofficialBuild();/\/\/ AutoUpdaterDialog::warnAboutUnofficialBuild();/' $sourceRoot/src/duckstation-qt/qthost.cpp

    # Désactivation complète de la vérification automatique des mises à jour (géré par NixOS / GitHub Actions)
    sed -i 's/g_main_window->startupUpdateCheck();/\/\/ g_main_window->startupUpdateCheck();/' $sourceRoot/src/duckstation-qt/qthost.cpp
    sed -i '/void MainWindow::startupUpdateCheck()/{n;s/{/{\n  return;/}' $sourceRoot/src/duckstation-qt/mainwindow.cpp
    sed -i '/void MainWindow::checkForUpdates(bool display_message, bool ignore_skipped_updates)/{n;s/{/{\n  return;/}' $sourceRoot/src/duckstation-qt/mainwindow.cpp
    sed -i '/void AutoUpdaterDialog::queueUpdateCheck(bool display_errors, bool ignore_skipped_updates)/{n;s/{/{\n  emit updateCheckCompleted(false);\n  return;/}' $sourceRoot/src/duckstation-qt/autoupdaterdialog.cpp
    sed -i 's/connect(m_ui.actionCheckForUpdates, &QAction::triggered/m_ui.actionCheckForUpdates->setVisible(false);\n  connect(m_ui.actionCheckForUpdates, \&QAction::triggered/' $sourceRoot/src/duckstation-qt/mainwindow.cpp
    sed -i '/m_ui.autoUpdateCurrentVersion->setText/a \    m_ui.updatesGroup->setVisible(false);' $sourceRoot/src/duckstation-qt/interfacesettingswidget.cpp

    # Configuration des RPATH pour tous les binaires et bibliothèques précompilés Qt
    ORIGIN='$ORIGIN'
    for bin in $(find $sourceRoot/dep/prebuilt/linux-x64 -type f -executable); do
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$bin" 2>/dev/null || true
      patchelf --set-rpath "$ORIGIN/../lib:${libPath}" "$bin" 2>/dev/null || true
    done

    for so in $(find $sourceRoot/dep/prebuilt/linux-x64/lib -type f -name "*.so*"); do
      patchelf --set-rpath "$ORIGIN:${libPath}" "$so" 2>/dev/null || true
    done
  '';

  preConfigure = ''
    PREBUILT_LIB="$(find "$NIX_BUILD_TOP" -type d -path '*/dep/prebuilt/linux-x64/lib' | head -n 1)"
    export LD_LIBRARY_PATH="$PREBUILT_LIB:${libPath}:''${LD_LIBRARY_PATH:-}"
  '';

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_CXX_SCAN_FOR_MODULES=OFF"
    "-DCMAKE_EXE_LINKER_FLAGS_INIT=-fuse-ld=lld"
    "-DCMAKE_MODULE_LINKER_FLAGS_INIT=-fuse-ld=lld"
    "-DCMAKE_SHARED_LINKER_FLAGS_INIT=-fuse-ld=lld"
    "-DUSE_WAYLAND=ON"
    "-DUSE_DRMKMS=ON"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/duckstation/lib $out/share/applications $out/share/icons/hicolor/512x512/apps

    # Copie du binaire Qt
    cp bin/duckstation-qt $out/share/duckstation/duckstation-qt
    ln -s $out/share/duckstation/duckstation-qt $out/bin/duckstation-qt
    ln -s $out/share/duckstation/duckstation-qt $out/bin/duckstation
    ln -s $out/share/duckstation/duckstation-qt $out/bin/duckstation-nogui

    # Copie uniquement des bibliothèques dynamiques .so (évite les fichiers .o et .a)
    if [ -d ../dep/prebuilt/linux-x64/lib ]; then
      find ../dep/prebuilt/linux-x64/lib -maxdepth 1 \( -type f -o -type l \) -name "*.so*" -exec cp -d {} $out/share/duckstation/lib/ \;
    fi

    # Copie des plugins Qt précompilés (plateformes Wayland/XCB, etc.)
    if [ -d ../dep/prebuilt/linux-x64/plugins ]; then
      cp -r ../dep/prebuilt/linux-x64/plugins $out/share/duckstation/
    fi

    # Copie des ressources
    if [ -d bin/resources ]; then
      cp -r bin/resources $out/share/duckstation/
    fi
    if [ -d bin/translations ]; then
      cp -r bin/translations $out/share/duckstation/
    fi

    # Raccourci de bureau et icône
    if [ -f ../scripts/appimage/org.duckstation.DuckStation.png ]; then
      install -m 644 ../scripts/appimage/org.duckstation.DuckStation.png $out/share/icons/hicolor/512x512/apps/duckstation.png
      install -m 644 ../scripts/appimage/org.duckstation.DuckStation.png $out/share/icons/hicolor/512x512/apps/org.duckstation.DuckStation.png
    fi

    cat << 'DESKTOP_EOF' > $out/share/applications/duckstation.desktop
[Desktop Entry]
Type=Application
Name=DuckStation
GenericName=PlayStation 1 Emulator
Comment=Fast and accurate PlayStation 1 (PSX) emulator
Exec=duckstation-qt %f
Icon=duckstation
Categories=Game;Emulator;
Keywords=playstation;ps1;psx;emulator;
Terminal=false
StartupWMClass=duckstation-qt
DESKTOP_EOF

    runHook postInstall
  '';

  preFixup = ''
    ORIGIN='$ORIGIN'
    RUNTIME_RPATH="$ORIGIN/lib:$out/share/duckstation/lib:${libPath}:${lib.makeLibraryPath buildInputs}"
    patchelf --set-rpath "$RUNTIME_RPATH" "$out/share/duckstation/duckstation-qt"

    addAutoPatchelfSearchPath "$out/share/duckstation/lib"
    if [ -d "$out/share/duckstation/plugins" ]; then
      addAutoPatchelfSearchPath "$out/share/duckstation/plugins"
    fi
  '';

  postFixup = ''
    wrapProgram $out/share/duckstation/duckstation-qt \
      --prefix QT_PLUGIN_PATH : "$out/share/duckstation/plugins" \
      --prefix PATH : "${lib.makeBinPath [ vulkan-loader ]}" \
      --prefix LD_LIBRARY_PATH : "${libPath}"
  '';

  meta = with lib; {
    description = "Fast and accurate PlayStation 1 (PSX) emulator";
    homepage = "https://github.com/stenzek/duckstation";
    license = licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "duckstation-qt";
  };
}
