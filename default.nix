{ sources ? import ./nix/sources.nix # set
, nixpkgs ? sources.nixpkgs # path
, pkgs ? import nixpkgs {
  overlays = [ (import ./patched) ];
} # set. only {pkgs} is used below
}:

rec {
  mk-passwd = import "${sources.mk-passwd}/${sources.mk-passwd.version}" { };
  nixsys = nix-sys;
  nixsys-preprocess = pkgs.callPackage ./preprocess/package.nix { };
  nix-sys = pkgs.callPackage ./nix-sys {
    inherit (pkgs.pkgsStatic) stdenv;
    inherit nixsys-preprocess;
  };
  pending = { tinyssh = pkgs.callPackage ./pending/tinyssh { }; };

  os = pkgs.callPackage ./os { inherit nixsys pending mk-passwd; };
  inherit pkgs;
}
