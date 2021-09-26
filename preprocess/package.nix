{ lib, haskell, version ? "8107" }:

let
  reckless = drv: with haskell.lib; unmarkBroken (dontCheck (doJailbreak drv));

  packages = haskell.packages."ghc${version}".override {
    overrides = self: super: {
      state-plus = reckless super.state-plus;
      test-simple = reckless super.test-simple;
    };
  };
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
