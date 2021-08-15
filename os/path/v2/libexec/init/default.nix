{ lib, substituteAll, busybox, runit }:

substituteAll {
  name = "v2+libexec+init";
  src = ./init.in;
  path = lib.makeBinPath [ busybox runit ];

  inherit busybox;
}
