{ busybox, writeText, nixFlakes, sinit, dropbear, buildEnv, runCommand }:
let
  usr = buildEnv {
    name = "mount-usr";
    paths = [ nixFlakes busybox sinit dropbear ];
    pathsToLink = [ "/bin" "/share" ];
  };
in { inherit usr; }
