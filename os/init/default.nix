{ lib, stdenv, writeText, substituteAll, busybox, fetchgit, runit }:
let
  shutdown = action:
    substituteAll {
      name = action;
      src = ./shutdown;
      isExecutable = true;
      path = lib.makeBinPath [ busybox runit ];
      inherit busybox;
    };
  reboot = shutdown "reboot";
  poweroff = shutdown "poweroff";
in rec {
  stage1 = substituteAll {
    src = ./init-stage1;
    isExecutable = true;
    path = lib.makeBinPath [ busybox ];
    inherit busybox;
  };
  stage2 = substituteAll {
    src = ./init-stage2;
    isExecutable = true;
    path = lib.makeBinPath [ busybox runit ];
    inherit busybox;
  };
  sinit = import ../sinit {
    inherit fetchgit stdenv;
    config-file = writeText "config.h" ''
      static char *const rcinitcmd[]     = { "${stage2}", NULL };
      static char *const rcrebootcmd[]   = { "${reboot}", NULL };
      static char *const rcpoweroffcmd[] = { "${poweroff}", NULL };
    '';
  };
}

