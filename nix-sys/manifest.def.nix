{ writeText, hello }:
let
  manifest = {
    copy = {
      "/etc/nix-sys.banner" = {
        path = writeText "banner.txt" "Configured with nix-sys";
        mode = "0444";
      };
    };
    exec = "${hello}/bin/hello";
  };
in writeText "manifest.json" (builtins.toJSON manifest)
