{ writeText }:
let
  manifest = {
    copy = {
      "/etc/nix-sys.banner" = {
        path = writeText "banner.txt" "Configured with nix-sys";
        mode = "0444";
      };
    };
  };
in writeText "manifest.json" (builtins.toJSON manifest)
