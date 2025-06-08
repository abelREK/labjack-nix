{pkgs ? import <nixpkgs> {}}:
pkgs.stdenv.mkDerivation rec {
  pname = "commander-cli";
  version = "1.18.1";

  src = pkgs.fetchurl {
    url = "https://github.com/abeljim/commander-cli-nix/releases/download/v1.18.1/commander_cli_linux_1.18.1.zip";
    sha256 = "1vsyv0f2yv2y5d49khjjfgaa04jm7yc4mw5s9s5rhfaj3cdazgmr";
  };

  buildInputs = [
    pkgs.libarchive
    pkgs.krb5
    pkgs.stdenv.cc.cc.lib
    pkgs.glib
    pkgs.dbus
  ];

  nativeBuildInputs = [
    pkgs.autoPatchelfHook
  ];

  unpackPhase = ''
    bsdtar -xf $src
  '';

  installPhase = ''
    mkdir -p $out/bin
    mv commander-cli $out/
    chmod +x $out/commander-cli/commander-cli
    ln -s $out/commander-cli/commander-cli $out/bin/commander-cli
  '';

  runtimeDependencies = [
    pkgs.krb5
    pkgs.stdenv.cc.cc.lib
    pkgs.glib
    pkgs.dbus
  ];

  meta = with pkgs.lib; {
    description = "Silicon Labs Commander CLI";
    homepage = "https://www.silabs.com/developer-tools/simplicity-studio/simplicity-commander";
    license = licenses.unfree;
    platforms = platforms.linux;
    maintainers = with maintainers; [abeljim];
  };
}
