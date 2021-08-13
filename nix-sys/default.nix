{ stdenv, tinycdb, nixsys-preprocess, redo-c, cproto, linuxHeaders ? null
, writeText, manifest ? import ./manifest.def.nix { inherit writeText; } }:
assert manifest != null;
let
in stdenv.mkDerivation {
  name = "nix-sys";
  src = ./.;
  outputs = [ "out" "cdb" "config" ];
  nativeBuildInputs = [ nixsys-preprocess redo-c cproto ];
  buildInputs = [ tinycdb linuxHeaders ];
  configurePhase = ''
    mkdir conf
    echo $out > conf/out
    echo $cdb > conf/cdb
    cp "$manifest" conf/manifest
    echo "${stdenv.cc.targetPrefix}cc -static -O2" > conf/cc
    echo "${stdenv.cc.targetPrefix}cc" > conf/ld
    echo "${if linuxHeaders != null then "enable" else "disable"}" \
      > conf/feature-chattr
  '';
  buildPhase = "redo";
  installPhase = "./install.sh";
  postFixup = "rm -fr $out/nix-support";
  allowSubstitutes = false;

  inherit manifest;
}
