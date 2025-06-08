{pkgs ? import <nixpkgs> {system = "x86_64-linux";}}:
pkgs.stdenv.mkDerivation rec {
  pname = "labjack-ljm";
  version = "25.02.12";

  src = pkgs.fetchurl {
    url = "https://files.labjack.com/installers/LJM/Linux/x64/beta/LabJack-LJM_2025-02-12.zip";
    sha256 = "1cypdsyd4ap9fcdv0xc5djlbxg1v6ihbdw15qbr5ii80iyga3sk7";
  };

  nativeBuildInputs = with pkgs; [
    unzip
    makeself
    autoPatchelfHook
    file
    patchelf
  ];

  buildInputs = with pkgs; [
    glibc
    libusb1
    stdenv.cc.cc.lib
    # Add more dependencies here if needed
  ];

  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack

    unzip $src

    mkdir -p extract_temp
    cd extract_temp

    chmod +x ../labjack_ljm_installer.run

    ../labjack_ljm_installer.run --noexec --target ./extracted

    runHook postUnpack
  '';

  configurePhase = ''
    runHook preConfigure

    cd extracted

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out

    if [ -d ljm ]; then
      echo "Installing LJM library components..."

      if [ -d ljm/lib ]; then
        mkdir -p $out/lib
        cp -r ljm/lib/* $out/lib/

        cd $out/lib
        if [ -f libLabJackM.so.1.23.4 ]; then
          ln -sf libLabJackM.so.1.23.4 libLabJackM.so.1
          ln -sf libLabJackM.so.1.23.4 libLabJackM.so
        fi
        cd - > /dev/null
      fi

      if [ -d ljm/include ]; then
        mkdir -p $out/include
        cp -r ljm/include/* $out/include/
      fi

      if [ -d ljm/share ]; then
        mkdir -p $out/share/doc/${pname}
        cp -r ljm/share/* $out/share/doc/${pname}/
      fi
    fi

    find . -name "*.rules" -exec mkdir -p $out/lib/udev/rules.d \; -exec cp {} $out/lib/udev/rules.d/ \;

    echo "Installation completed successfully"
    echo "Installed files:"
    find $out -type f | head -20

    runHook postInstall
  '';

  runtimeDependencies = with pkgs; [
    libusb1
    glibc
    stdenv.cc.cc.lib
  ];

  postFixup = ''
    runtimeRPath="${pkgs.lib.makeLibraryPath runtimeDependencies}:$out/lib"

    if [ -d "$out/lib" ]; then
      echo "Patching shared libraries..."
      find "$out/lib" -name "*.so*" -type f | while read -r lib; do
        if patchelf --print-rpath "$lib" > /dev/null 2>&1; then
          patchelf --set-rpath "$runtimeRPath" "$lib"
        fi
      done
    fi
  '';

  meta = with pkgs.lib; {
    description = "LabJack LJM (LabJack Manager) software for T4, T7, and T8 devices";
    homepage = "https://support.labjack.com/docs/ljm-software-installer-downloads-t4-t7-t8-digit";
    license = licenses.unfree;
    platforms = ["x86_64-linux"];
    maintainers = with maintainers; [
      abeljim
    ];
  };
}
