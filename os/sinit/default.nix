{ stdenv, fetchgit, config-file }:

stdenv.mkDerivation rec {
  pname = "sinit";
  version = "1.1";
  src = fetchgit {
    url = "git://git.suckless.org/sinit";
    rev = "v${version}";
    sha256 = "0v1f9j7fc968ppb08jpd71bc7rbxgnivifix765544k05j1f9man";
  };
  preConfigure = ''
    rm config.def.h
    cp ${config-file} config.h
  '';
  makeFlags = [
    "CC=${stdenv.cc.targetPrefix}cc"
    "PREFIX=/"
    "DESTDIR=${placeholder "out"}"
    "MANPREFIX=/share/man"
  ];
}
