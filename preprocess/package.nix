{ lib, fetchgit, haskell, version ? "8107" }:

let
  reckless = drv: with haskell.lib; unmarkBroken (dontCheck (doJailbreak drv));

  packages = haskell.packages."ghc${version}".override {
    overrides = self: super: {
      state-plus = reckless super.state-plus;
      test-simple = reckless super.test-simple;
      linux-capabilities =
        let src = fetchgit {
          url = "https://git.sr.ht/~kaction/linux-capabilities";
          rev = "v1.1.0.0";
          sha256 = "043by5pimkxlxpr33kb8d1pnx06jyw3pbdyk635vga8hiqz8bifg";
        };
        in self.callCabal2nix "linux-capabilities" src { };
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
