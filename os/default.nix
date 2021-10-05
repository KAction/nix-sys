{ nixsys, pending, substituteAll, writeText, runCommand, callPackage, pkgs }:
let
  kernel = callPackage ./linux { };
  kernel-sha256 = builtins.substring 11 32 kernel;
  init-stage1 = let path = with pkgs; lib.makeBinPath [ busybox ];
  in substituteAll {
    src = ./init/init-stage1;
    isExecutable = true;
    inherit path;
    inherit (pkgs) busybox;
  };
  init-stage2 = let path = with pkgs; lib.makeBinPath [ busybox runit ];
  in substituteAll {
    src = ./init/init-stage2;
    isExecutable = true;
    inherit path;
    inherit (pkgs) busybox;
  };
  shutdown = action:
    substituteAll {
      name = action;
      src = ./init/shutdown;
      isExecutable = true;
      path = with pkgs; lib.makeBinPath [ busybox runit ];
      inherit (pkgs) busybox;
    };
  reboot = shutdown "reboot";
  poweroff = shutdown "poweroff";

  sinit = callPackage ./sinit {
    inherit (pkgs.pkgsStatic) stdenv;
    config-file = pkgs.writeText "config.h" ''
      static char *const rcinitcmd[]     = { "${init-stage2}", NULL };
      static char *const rcrebootcmd[]   = { "${reboot}", NULL };
      static char *const rcpoweroffcmd[] = { "${poweroff}", NULL };
    '';
  };

  service =
    # logscript has default, since in most cases redirecting stdout/stderr
    # is disirable, otherwise /dev/tty1 will be cluttered.
    { name, runscript, logscript ? "svlogd -ttt /state/log/${name}"
    , dependencies ? (with pkgs; [ runit execline busybox ]) }:
    pkgs.stdenv.mkDerivation {
      name = "${name}.sv";
      dontUnpack = true;
      installPhase = ''
        mkdir $out
        cat << EOF > $out/run
        #!$execline/bin/execlineb -P
        export PATH $path
        fdmove -c 2 1
        $runscript
        EOF
        chmod +x $out/run

        if [ "$logscript" ] ; then
          mkdir $out/log
          cat << EOF > $out/log/run
        #!$execline/bin/execlineb -P
        export PATH $path
        fdmove -c 2 1
        $logscript
        EOF
          chmod +x $out/log/run
        fi
        ln -sf /state/supervise/$name.sv $out/supervise
      '';
      path = pkgs.lib.makeBinPath dependencies;
      inherit runscript logscript;
      inherit (pkgs) execline;
    };
  manifest = {
    symlink = {
      "/service/getty-tty1" = {
        path = service {
          name = "getty-tty1";
          runscript = "getty -l login -i 0 /dev/tty1";
        };
      };
      "/service/nix-daemon" = {
        path = service {
          name = "nix-daemon";
          runscript = "exec -a nix-daemon ${pkgs.nix}/bin/nix-daemon";
        };
      };
      "/service/net-eth0" = {
        path = service {
          name = "net-eth0";
          runscript = ''
            if { ip link set up dev eth0 }
            udhcpc -R -i eth0 -f
          '';
        };
      };
      "/service/tinyssh" = {
        path = service {
          name = "tinyssh";
          runscript = ''
            busybox tcpsvd 0 23 tinysshd -v /state/identity/tinyssh
          '';
          dependencies = with pkgs; [ busybox execline pending.tinyssh ];
        };
      };

      "/service/sshd" = {
        path = service {
          name = "sshd";
          runscript = ''
            exec -a dropbear
              ${pkgs.dropbear}/bin/dropbear -sFEr /state/identity/sshd/ed25519
          '';
        };
      };
    };
    mkdir = {
      "/boot/kernel" = { mode = "755"; };
      "/boot/kernel/hash" = { mode = "755"; };
      "/boot/kernel/conf" = { mode = "755"; };
      "/state/supervise" = { mode = "700"; };
      "/state/log/sshd" = { mode = "700"; };
      "/state/log/tinyssh" = { mode = "700"; };
      "/state/log/net-eth0" = { mode = "700"; };
      "/state/log/nix-daemon" = { mode = "700"; };
      "/state/log/getty-tty1" = { mode = "700"; };
      "/state/identity/sshd" = { mode = "700"; };
    };
    exec = let
      path = with pkgs;
        lib.makeBinPath [
          sinit
          nix
          tinycdb
          busybox
          pending.tinyssh
          dropbear
          lilo
        ];
    in pkgs.writeScript "post-install" (
      # ssh server key can't be generated at build time, or it will be the same
      # at all targets
      ''
        #!${pkgs.busybox}/bin/sh -eu
        umask 022
        export PATH=${path}
        if ! [ -f /state/identity/sshd/ed25519 ] ; then
          dropbearkey -t ed25519 -f /state/identity/sshd/ed25519
        fi
        if ! [ -f /state/identity/tinyssh/ed25519.pk ] ; then
          tinysshd-makekey /state/identity/tinyssh
        fi

        # busybox sh does not support "-a" option of "exec" builtin.
        if [ $$ = 1 ] ; then
          exec sinit
        fi
      ''
      # By design, nix-sys removes files from previous config. We don't want
      # it to happen with kernels, so this have to be done imperatively in
      # post-install script.
      + ''
        epoch=`date +%s`
        now=`date -d @$epoch +%Y-%m-%d.%s`
      ''
      # LILO has very small limit on length of label, so we barely can fit only
      # timestamp, nothing more.
      + ''
        label=`date -d @$epoch +%Y%m%d%H%S`
        if ! test -f /boot/kernel/hash/${kernel-sha256} ; then
          cp ${kernel} /boot/kernel/hash/${kernel-sha256}
        fi
      ''
      # Storing kernel by its hash (well, output hash) and hard-linking kernel
      # afterward saves storage on /boot partition which is usually quite small
      # (e.g Alpine linux dedicates merely 90Mb to it).
      #
      # Now, for every new invocation of nix-sys, we create new entry in
      # bootloader, while taking care that two consequent calls to nix-sys
      # (with same output hash) do not create duplicate entries.
      + ''
        current="none"
        ! test -r /boot/current || current=`cat /boot/current`

        if [ $out != $current ] ; then
          this=`echo $out | cut -b12-43`
          mkdir -p /boot/kernel/conf/$now
          ln /boot/kernel/hash/${kernel-sha256} /boot/kernel/conf/$now/image
          ln -sf $out /boot/kernel/conf/$now/nix-sys.gc
          nix-store --add-root /boot/kernel/conf/$now/nix-sys.gc -r
          cat << EOF > /boot/kernel/conf/$now/lilo.conf
        image = /boot/kernel/conf/$now/image
          label  = "$label"
          append = "init=${init-stage1} nix-sys=$out"
          read-only
        EOF
        fi

        # Regenerate /boot/lilo.conf
          cat << EOF > /boot/lilo.conf~
        lba32
        boot = /dev/sda
        root = /dev/sda3
        install = menu
        prompt
        timeout = 100
        EOF

          for x in `ls /boot/kernel/conf/*/lilo.conf | tac` ; do
            cat "$x" >> /boot/lilo.conf~
          done

          cat << EOF >> /boot/lilo.conf~
        image = /boot/bzImage-2
          label = "Linux-2"
          read-only

        image = /boot/bzImage-1
          label = "Linux-1"
          read-only
        EOF

        if ! cmp -s /boot/lilo.conf /boot/lilo.conf~ ; then
          mv /boot/lilo.conf~ /boot/lilo.conf
          lilo -C /boot/lilo.conf
        fi
        rm -f /boot/lilo.conf~

        echo $out > /boot/current
      '');
  };
in nixsys.override {
  manifest = writeText "manifest.json" (builtins.toJSON manifest);
}
