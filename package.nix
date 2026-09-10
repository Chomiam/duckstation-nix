{ lib
, stdenv
, fetchFromGitHub
, fetchurl
, cmake
, ninja
, pkg-config
, patchelf
, llvmPackages
, kdePackages
, curl
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

in
stdenv.mkDerivation rec {
  pname = "duckstation";
  inherit version src;

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    patchelf
    kdePackages.extra-cmake-modules
    llvmPackages.clang
    llvmPackages.lld
    makeWrapper
    autoPatchelfHook
  ];

  buildInputs = [
    curl
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

  postUnpack = ''
    mkdir -p $sourceRoot/dep/prebuilt/linux-x64
    tar -xf ${prebuiltDeps} -C $sourceRoot/dep/prebuilt
    cp ${cheats} $sourceRoot/data/resources/cheats.zip
    cp ${patches} $sourceRoot/data/resources/patches.zip
    chmod -R u+w $sourceRoot/dep/prebuilt

    # Neutralisation du contrôle d'environnement hostile
    sed -i 's/message(FATAL_ERROR "Unsupported environment.")/message(STATUS "Building on NixOS")/g' $sourceRoot/CMakeModules/DuckStationBuildSummary.cmake

    # Patch des outils de build Qt précompilés (moc, uic, rcc, lrelease, etc.)
    for bin in $(find $sourceRoot/dep/prebuilt/linux-x64 -type f -executable); do
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$bin" 2>/dev/null || true
      patchelf --set-rpath "$sourceRoot/dep/prebuilt/linux-x64/lib:${stdenv.cc.cc.lib}/lib" "$bin" 2>/dev/null || true
    done
  '';

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_C_COMPILER=clang"
    "-DCMAKE_CXX_COMPILER=clang++"
    "-DCMAKE_EXE_LINKER_FLAGS_INIT=-fuse-ld=lld"
    "-DCMAKE_MODULE_LINKER_FLAGS_INIT=-fuse-ld=lld"
    "-DCMAKE_SHARED_LINKER_FLAGS_INIT=-fuse-ld=lld"
    "-DUSE_WAYLAND=ON"
    "-DUSE_DRMKMS=ON"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/duckstation $out/share/applications $out/share/icons/hicolor/scalable/apps

    # Copie du binaire Qt
    cp bin/duckstation-qt $out/share/duckstation/duckstation-qt
    ln -s $out/share/duckstation/duckstation-qt $out/bin/duckstation-qt
    ln -s $out/share/duckstation/duckstation-qt $out/bin/duckstation
    ln -s $out/share/duckstation/duckstation-qt $out/bin/duckstation-nogui

    # Copie des bibliothèques précompilées indispensables au runtime
    if [ -d ../dep/prebuilt/linux-x64/lib ]; then
      mkdir -p $out/share/duckstation/lib
      cp -a ../dep/prebuilt/linux-x64/lib/* $out/share/duckstation/lib/
    fi

    # Copie des ressources
    if [ -d bin/resources ]; then
      cp -r bin/resources $out/share/duckstation/
    fi
    if [ -d bin/translations ]; then
      cp -r bin/translations $out/share/duckstation/
    fi

    # Raccourci de bureau et icône
    install -m 644 ../data/resources/duckstation.png $out/share/icons/hicolor/scalable/apps/duckstation.png
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
    addAutoPatchelfSearchPath "$out/share/duckstation/lib"
  '';

  postFixup = ''
    wrapProgram $out/share/duckstation/duckstation-qt \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}:$out/share/duckstation/lib" \
      --prefix PATH : "${lib.makeBinPath [ vulkan-loader ]}"
  '';

  meta = with lib; {
    description = "Fast and accurate PlayStation 1 (PSX) emulator";
    homepage = "https://github.com/stenzek/duckstation";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "duckstation-qt";
  };
}
