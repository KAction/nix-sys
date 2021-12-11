{ lib, stdenv, fetchurl, ncurses, perl, openssl, flex, bison, elfutils, bc }:

stdenv.mkDerivation rec {
  pname = "linux";
  version = "5.15.7";
  src = fetchurl {
    url =
      "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${version}.tar.xz";
    sha256 = "1caxpqmik6gkhk3437pcgfq6vvlbs962hylgbh64iizd76l5142x";
  };
  nativeBuildInputs = [ ncurses perl openssl flex bison elfutils bc ];
  configurePhase = ''
    # patchShebangs ./scripts/*
    # find ./scripts
    cp ${./config.txt} .config
  '';
  installPhase = ''
    cp arch/x86/boot/bzImage $out
  '';
}
