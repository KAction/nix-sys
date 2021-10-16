{ writeText, cwrap, busybox }:
let
  manifest = {
    copy = {
      "/bin/sh" = {
        path = cwrap "${busybox}/bin/sh";
        mode = "0555";
      };
    };
  };
in writeText "manifest.json" (builtins.toJSON manifest)
