{ lib, stdenv, fetchurl, ncurses, perl, openssl, flex, bison, libelf, bc }:

stdenv.mkDerivation rec {
  pname = "linux";
  version = "5.4.149";
  src = fetchurl {
    url =
      "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${version}.tar.xz";
    sha256 = "1s1zka0iay0drgkdnmzf587jbrg1gx13xv26k5r1qc7dik8xc6p7";
  };
  nativeBuildInputs = [ ncurses perl openssl flex bison libelf bc ];
  configurePhase = ''
    # patchShebangs ./scripts/*
    # find ./scripts
    cp ${./config.txt} .config
  '';
  installPhase = ''
    cp arch/x86/boot/bzImage $out
  '';
}
