{ lib, substituteAll, syslinux, busybox, nix }:

substituteAll {
  name = "setup-bootloader";
  src = ./setup-bootloader.sh;
  dir = "/bin";
  isExecutable = true;

  path = lib.makeBinPath [ syslinux busybox nix ];
  inherit busybox syslinux;
}
