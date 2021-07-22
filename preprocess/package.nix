{ lib, haskell, version ? "8104" }:

let
  packages = haskell.packages."ghc${version}";
  drv = packages.callCabal2nix "nixsys-preprocess" ./. { };
  tools = with packages; [
    cabal-install
    hpack
    hlint
    ormolu
    haskell-language-server
  ];

  dev = drv.env.overrideAttrs (attr: {
    buildInputs = attr.buildInputs ++ tools;
    shellHook = "hpack";
  });

in if lib.inNixShell then dev else drv
