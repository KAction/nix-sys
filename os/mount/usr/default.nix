{ writeText, busybox, nixFlakes, sinit, tinyssh, execline, buildEnv, callPackage }:
let
  shutdown = callPackage ./shutdown { };

  manifest = {
    symlink."/usr".path = buildEnv {
      name = "mount-usr";
      paths = [ nixFlakes shutdown busybox execline sinit tinyssh ];
      pathsToLink = [ "/bin" "/share" ];
    };
  };

in writeText "manifest.json" (builtins.toJSON manifest)
