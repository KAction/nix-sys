{ sources ? import ./nix/sources.nix # set
, nixpkgs ? sources.nixpkgs # path
, pkgs ? import nixpkgs { } # set. only {pkgs} is used below
}:

{
  nixsys-preprocess = pkgs.callPackage ./preprocess/package.nix { };
}
