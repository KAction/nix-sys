{ busybox, writeText, nixFlakes, sinit, dropbear, buildEnv, runCommand }:
let
  bin = runCommand "mount-bin" { inherit busybox; } ''
    mkdir -p $out
    ln -sf $busybox/bin/sh $out/sh
  '';
  usr = buildEnv {
    name = "mount-usr";
    paths = [ nixFlakes busybox sinit dropbear ];
    pathsToLink = [ "/bin" "/share" ];
  };
in { inherit bin usr; }
