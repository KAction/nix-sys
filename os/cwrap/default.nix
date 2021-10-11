{ lib, stdenv, fasm, binary }:

stdenv.mkDerivation {
  name = "cwrap";
  buildInputs = [ fasm ];
  dontUnpack = true;

  buildPhase = ''
    mkdir arch
    cp ${arch/x86_64-linux.fasm} arch/x86_64-linux.fasm
    substituteAll ${./cwrap.fasm} cwrap.fasm
    fasm cwrap.fasm
  '';
  installPhase = "cp cwrap $out";
  inherit binary;
}
