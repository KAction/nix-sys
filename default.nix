{ sources ? import ./nix/sources.nix # set
, nixpkgs ? sources.nixpkgs # path
, pkgs ? import nixpkgs { } # set. only {pkgs} is used below
}:

rec {
  nixsys = nix-sys;
  nixsys-preprocess = pkgs.callPackage ./preprocess/package.nix { };
  nix-sys = pkgs.callPackage ./nix-sys {
    inherit (pkgs.pkgsStatic) stdenv;
    inherit nixsys-preprocess;
  };
}
