{
  description = "LABJACK LJM";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
  };
  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
  in {
    packages.${system}.labjack-ljm = pkgs.stdenv.mkDerivation rec {
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
        # Additional dependencies for Kipling GUI
        # gtk3
        # glib
        # nss
        # nspr
        # atk
        # at-spi2-atk
        # cups
        # dbus
        # gtk3
        # gdk-pixbuf
        # cairo
        # pango
        # harfbuzz
        # freetype
        # fontconfig
        # libdrm
        # xorg.libX11
        # xorg.libXcomposite
        # xorg.libXdamage
        # xorg.libXext
        # xorg.libXfixes
        # xorg.libXrandr
        # xorg.libxcb
        # mesa
        # expat
        # alsa-lib
      ];

      # Don't strip binaries as it might break the installer
      dontStrip = true;

      # Remove the debug output from unpack since we know the structure now
      unpackPhase = ''
        runHook preUnpack

        # Extract the zip file
        unzip $src

        # Create a working directory and extract the makeself archive
        mkdir -p extract_temp
        cd extract_temp

        # Make the .run file executable and extract it
        chmod +x ../labjack_ljm_installer.run

        # Extract the makeself archive without running the setup script
        ../labjack_ljm_installer.run --noexec --target ./extracted

        runHook postUnpack
      '';

      configurePhase = ''
        runHook preConfigure

        cd extracted

        # The makeself script mentions it extracts to "labjack_software" directory
        # and runs "./resources/setup.sh"

        runHook postConfigure
      '';

      buildPhase = ''
        runHook preBuild

        # Usually LabJack installers are pre-compiled binaries
        # No compilation needed

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        mkdir -p $out

        # Install LJM library components
        if [ -d ljm ]; then
          echo "Installing LJM library components..."

          # Install shared library
          if [ -d ljm/lib ]; then
            mkdir -p $out/lib
            cp -r ljm/lib/* $out/lib/

            # Create symlinks for the library
            cd $out/lib
            if [ -f libLabJackM.so.1.23.4 ]; then
              ln -sf libLabJackM.so.1.23.4 libLabJackM.so.1
              ln -sf libLabJackM.so.1.23.4 libLabJackM.so
            fi
            cd - > /dev/null
          fi


          # Install headers
          if [ -d ljm/include ]; then
            mkdir -p $out/include
            cp -r ljm/include/* $out/include/
          fi


          # Install documentation and version info
          if [ -d ljm/share ]; then
            mkdir -p $out/share/doc/${pname}
            cp -r ljm/share/* $out/share/doc/${pname}/
          fi
        fi

        # Install Kipling GUI application
        # if [ -d labjack_kipling ]; then
        #   echo "Installing Kipling GUI application..."
        #   mkdir -p $out/bin $out/share/kipling
        #
        #   # Copy all Kipling files
        #   cp -r labjack_kipling/* $out/share/kipling/
        #
        #   # Make the main executable actually executable
        #   chmod +x $out/share/kipling/Kipling
        #
        #   # Create a wrapper script in bin
        #   cat > $out/bin/kipling <<EOF
        #   #!/bin/bash
        #   cd @out@/share/kipling
        #   exec ./Kipling "$@"
        #   EOF
        #   chmod +x $out/bin/kipling
        #
        #   # Substitute the @out@ placeholder
        #   substituteInPlace $out/bin/kipling --replace "@out@" "$out"
        # fi

        echo "passed gui"

        # Install any udev rules if they exist
        find . -name "*.rules" -exec mkdir -p $out/lib/udev/rules.d \; -exec cp {} $out/lib/udev/rules.d/ \;

        echo "Installation completed successfully"
        echo "Installed files:"
        find $out -type f | head -20

        runHook postInstall
      '';

      # Runtime dependencies that the LabJack software might need
      runtimeDependencies = with pkgs; [
        libusb1
        glibc
        stdenv.cc.cc.lib
        # Dependencies for Kipling GUI (Electron-based)
        # gtk3
        # glib
        # nss
        # nspr
        # atk
        # at-spi2-atk
        # cups
        # dbus
        # gdk-pixbuf
        # cairo
        # pango
        # harfbuzz
        # freetype
        # fontconfig
        # libdrm
        # xorg.libX11
        # xorg.libXcomposite
        # xorg.libXdamage
        # xorg.libXext
        # xorg.libXfixes
        # xorg.libXrandr
        # xorg.libxcb
        # mesa
        # expat
        # alsa-lib
      ];

      # Patch ELF files to work on NixOS
      postFixup = ''
        runtimeRPath="${pkgs.lib.makeLibraryPath runtimeDependencies}:$out/lib"

        # echo "Patching ELF binaries..."
        # echo "$out"
        # find "$out" -type f -executable -exec file {} \; | \
        #   grep -E "(ELF.*executable|ELF.*shared object)" | \
        #   cut -d: -f1 | \
        #   while read -r f; do
        #     echo "Patching $f"
        #     if patchelf --print-rpath "$f" > /dev/null 2>&1; then
        #       patchelf --set-rpath "$runtimeRPath" "$f"
        #     fi
        #   done

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
        longDescription = ''
          The LabJack LJM library provides a cross-platform interface for
          LabJack T4, T7, and T8 data acquisition devices. This package includes
          the shared libraries, headers, and utilities needed to communicate
          with LabJack devices over USB, Ethernet, or WiFi.
        '';
        homepage = "https://support.labjack.com/docs/ljm-software-installer-downloads-t4-t7-t8-digit";
        license = licenses.unfree;
        platforms = ["x86_64-linux"];
        maintainers = with maintainers; [abeljim];
      };
    };

    # Default package
    # packages.${system}.default = self.packages.${system}.labjack-ljm;

    # Development shell
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        self.packages.${system}.labjack-ljm
      ];

      shellHook = ''
        echo "LabJack LJM development environment"
        echo "LJM library path: ${self.packages.${system}.labjack-ljm}/lib"
        export LD_LIBRARY_PATH="${self.packages.${system}.labjack-ljm}/lib:$LD_LIBRARY_PATH"
      '';
    };
  };
}
