{ writeText, busybox, nixFlakes, sinit, tinyssh, buildEnv }:
let
  manifest = {
    symlink."/usr".path = buildEnv {
      name = "mount-usr";
      paths = [ nixFlakes busybox sinit tinyssh ];
      pathsToLink = [ "/bin" "/share" ];
    };
  };

in writeText "manifest.json" (builtins.toJSON manifest)
