{ stdenv, fasm }:
stdenv.mkDerivation {
  name = "shutdown";
  src = ./.;
  buildInputs = [ fasm ];
  buildPhase = ''
    echo 'CONFIG_SIGNAL = SIGUSR1' > .config
    fasm shutdown.fasm poweroff
    echo 'CONFIG_SIGNAL = SIGINT' > .config
    fasm shutdown.fasm reboot
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp reboot poweroff $out/bin
  '';
}
