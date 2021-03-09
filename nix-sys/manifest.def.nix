{ writeText }:
let
  manifest = {
    "/etc/nix-sys.banner" = {
      path = writeText "banner.txt" "Configured with nix-sys";
      action = "copy";
      mode = "0444";
    };
  };
in writeText "manifest.json" (builtins.toJSON manifest)
