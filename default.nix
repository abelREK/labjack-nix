{pkgs ? import <nixpkgs> {system = "x86_64-linux";}}: let
  # First build the raw LabJack package
  labjack-ljm-raw = pkgs.stdenv.mkDerivation rec {
    pname = "labjack-ljm-raw";
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
          mkdir -p $out/share/LabJack/LJM
          find ljm/share -name "ljm_constants.json" -exec cp {} $out/share/LabJack/LJM/ \;
          mkdir -p $out/share/doc/${pname}
          cp -r ljm/share/* $out/share/doc/${pname}/
        fi
      fi
      find . -name "*.rules" -exec mkdir -p $out/lib/udev/rules.d \; -exec cp {} $out/lib/udev/rules.d/ \;
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
        find "$out/lib" -name "*.so*" -type f | while read -r lib; do
          if patchelf --print-rpath "$lib" > /dev/null 2>&1; then
            patchelf --set-rpath "$runtimeRPath" "$lib"
          fi
        done
      fi
    '';
  };
in
  # Now create the FHS-wrapped package
  pkgs.buildFHSUserEnv {
    name = "labjack-ljm";

    targetPkgs = pkgs:
      with pkgs; [
        labjack-ljm-raw
        libusb1
        glibc
        gcc.cc.lib
        bash
        coreutils
      ];

    multiPkgs = pkgs:
      with pkgs; [
        # Add 32-bit libraries if your application needs them
      ];

    extraBuildCommands = ''
      # Create the directory structure that LabJack expects
      mkdir -p usr/local/share/LabJack/LJM
      mkdir -p usr/local/lib
      mkdir -p usr/local/include
      mkdir -p etc/udev/rules.d

      # Symlink the constants file to where LabJack expects it
      ln -sf ${labjack-ljm-raw}/share/LabJack/LJM/ljm_constants.json usr/local/share/LabJack/LJM/ljm_constants.json

      # Symlink libraries
      ln -sf ${labjack-ljm-raw}/lib/* usr/local/lib/

      # Symlink headers
      ln -sf ${labjack-ljm-raw}/include/* usr/local/include/

      # Symlink udev rules if they exist
      if [ -d "${labjack-ljm-raw}/lib/udev/rules.d" ]; then
        ln -sf ${labjack-ljm-raw}/lib/udev/rules.d/* etc/udev/rules.d/
      fi
    '';

    # Default to bash, but this can be overridden
    runScript = "bash";

    profile = ''
      export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
      export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
      export LIBRARY_PATH="/usr/local/lib:$LIBRARY_PATH"
      export C_INCLUDE_PATH="/usr/local/include:$C_INCLUDE_PATH"
      export CPLUS_INCLUDE_PATH="/usr/local/include:$CPLUS_INCLUDE_PATH"

      # Add /usr/local/lib to ldconfig cache simulation
      export NIX_LDFLAGS="-L/usr/local/lib $NIX_LDFLAGS"

      echo "LabJack LJM environment ready!"
      echo "Constants file: /usr/local/share/LabJack/LJM/ljm_constants.json"
      echo "Libraries: /usr/local/lib/libLabJackM.so*"
      echo "Headers: /usr/local/include/"
    '';

    meta = with pkgs.lib; {
      description = "LabJack LJM (LabJack Manager) software in FHS environment";
      homepage = "https://support.labjack.com/docs/ljm-software-installer-downloads-t4-t7-t8-digit";
      license = licenses.unfree;
      platforms = ["x86_64-linux"];
      maintainers = with maintainers; [
        abeljim
      ];
    };
  }
