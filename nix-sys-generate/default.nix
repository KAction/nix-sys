{ stdenv, writeScriptBin, execline, python3 }:
let
  python = python3.withPackages (p: with p; [ click pure-cdb jinja2 ]);
  script = stdenv.mkDerivation {
    name = "nix-sys-generate";
    dontUnpack = true;
    propagatedBuildInputs = [ python ];
    installPhase = ''
      mkdir -p $out/bin
      cp ${./nix-sys-generate.py} $out/bin/$name
      chmod +x $out/bin/$name
    '';
  };
in writeScriptBin "nix-sys-generate" ''
  #!${execline}/bin/execlineb -WS0
  ${script}/bin/nix-sys-generate --template-directory ${./templates} $@
''
