{ nixsys, stdenv, mk-passwd, pending, substituteAll, writeText, runCommand
, callPackage, syslinux, pkgs }:
let
  cwrap = binary: callPackage ./cwrap { inherit binary; };

  manifest.hook-sysctl = callPackage ./hooks/sysctl { };
  manifest.doas = callPackage ./suid/doas { inherit cwrap; };
  manifest.etc = callPackage ./mount/etc { inherit mk-passwd; };
  manifest.bin = callPackage ./mount/bin { inherit cwrap; };
  manifest.usr = callPackage ./mount/usr {
    inherit sinit;
    inherit (pending) tinyssh;
  };

  kernel = callPackage ./linux { };
  setup-bootloader = callPackage ./setup-bootloader { };
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
    { name, runscript, logscript ? "svlogd -ttt /state/log/${name}.1"
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
          ln -sf /state/supervise/log.$name $out/log/supervise
        fi
        ln -sf /state/supervise/$name $out/supervise
      '';
      path = pkgs.lib.makeBinPath dependencies;
      inherit runscript logscript;
      inherit (pkgs) execline;
    };
  manifest.main = let
    m = {
      copy = {
        "/etc/nix/nix.conf" = {
          path = writeText "nix.conf" ''
            experimental-features = flakes nix-command
            trusted-users = user
          '';
          mode = "0444";
        };
      };
      symlink = {
        "/dev/fd" = { path = "/proc/self/fd"; };
        "/dev/stdin" = { path = "/proc/self/fd/0"; };
        "/dev/stdout" = { path = "/proc/self/fd/1"; };
        "/dev/stderr" = { path = "/proc/self/fd/2"; };
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
        "/service/sshd" = {
          path = service {
            name = "sshd";
            runscript = ''
              busybox tcpsvd 0 22 tinysshd -v /state/identity/tinyssh
            '';
            dependencies = with pkgs; [ busybox execline pending.tinyssh ];
          };
        };
      };
      mkdir = {
        "/boot/kernel" = { mode = "755"; };
        "/boot/kernel/hash" = { mode = "755"; };
        "/boot/kernel/conf" = { mode = "755"; };
        "/state/supervise" = { mode = "700"; };
        "/state/log/sshd.1" = { mode = "700"; };
        "/state/log/tinyssh.1" = { mode = "700"; };
        "/state/log/net-eth0.1" = { mode = "700"; };
        "/state/log/nix-daemon.1" = { mode = "700"; };
        "/state/log/getty-tty1.1" = { mode = "700"; };
      };
      exec = let
        path = with pkgs;
          lib.makeBinPath [
            sinit
            busybox
            setup-bootloader
          ];
      in pkgs.writeScript "post-install" ''
          #!${pkgs.busybox}/bin/sh -eu
          umask 022
          export PATH=${path}
          run-parts --exit-on-error /etc/hooks
          if [ $$ = 1 ] ; then
            exec sinit
          fi
          setup-bootloader "$out" "${kernel}" "${init-stage1}"
        '';
    };
  in writeText "manifest.json" (builtins.toJSON m);

  united = stdenv.mkDerivation {
    name = "manifest.json";
    dontUnpack = true;
    buildInputs = [ pkgs.jq ];
    manifests = builtins.attrValues manifest;
    installPhase = ''
      jq --slurp 'reduce .[] as $item ({}; . * $item)' $manifests > $out
    '';
  };
in nixsys.override { manifest = united; }
