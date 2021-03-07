{
  description = "nix-sys -- minimalistic configuration management system";
  inputs.nixpkgs.url = "git+https://github.com/nixos/nixpkgs?tag=20.09";
  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      python3 = pkgs.python3.override {
        packageOverrides = import ./python-overrides.nix;
      };
      nix-sys-generate =
        pkgs.callPackage ./nix-sys-generate { inherit python3; };
      nix-sys = pkgs.callPackage ./nix-sys {
        inherit (pkgs.pkgsStatic) stdenv;
        inherit nix-sys-generate;
      };
    in {
      packages.x86_64-linux = { inherit nix-sys nix-sys-generate; };

      defaultPackage.x86_64-linux = self.packages.x86_64-linux.nix-sys;
    };
}
