{ nixsys, writeText, callPackage, pkgs }:
let
  service =
    # logscript has default, since in most cases redirecting stdout/stderr
    # is disirable, otherwise /dev/tty1 will be cluttered.
    { name, runscript
    , logscript ? "${pkgs.runit}/bin/svlogd -ttt /state/log/${name}" }:
    pkgs.stdenv.mkDerivation {
      name = "${name}.sv";
      dontUnpack = true;
      installPhase = ''
        mkdir $out
        cat << EOF > $out/run
        #!$execline/bin/execlineb -P
        fdmove -c 2 1
        $runscript
        EOF
        chmod +x $out/run

        if [ "$logscript" ] ; then
          mkdir $out/log
          cat << EOF > $out/log/run
        #!$execline/bin/execlineb -P
        fdmove -c 2 1
        $logscript
        EOF
          chmod +x $out/log/run
        fi
        ln -sf /state/supervise/$name.sv $out/supervise
      '';
      inherit runscript logscript;
      inherit (pkgs) execline;
    };
  manifest = {
    copy = {
      "/v2/libexec/init" = {
        path = callPackage ./path/v2/libexec/init { };
        mode = "555";
      };
      "/boot/kernel" = {
        path = callPackage ./linux { };
        mode = "444";
      };
    };
    symlink = {
      "/service/getty-tty1" = {
        path = service {
          name = "getty-tty1";
          runscript = ''
            ${pkgs.busybox}/bin/getty
              -l ${pkgs.busybox}/bin/login -i 0 /dev/tty1
          '';
        };
      };
      "/service/nix-daemon" = {
        path = service {
          name = "nix-daemon";
          runscript = "${pkgs.nix}/bin/nix-daemon";
        };
      };
      "/service/net-eth0" = {
        path = service {
          name = "net-eth0";
          runscript = ''
            if { ${pkgs.busybox}/bin/ip link set up dev eth0 }
            ${pkgs.busybox}/bin/udhcpc -R -i eth0 -f
          '';
        };
      };
      "/service/sshd" = {
        path = service {
          name = "sshd";
          runscript = ''
            ${pkgs.dropbear}/bin/dropbear -sFEr /state/identity/sshd/ed25519
          '';
        };
      };
    };
    mkdir = {
      "/state/supervise" = { mode = "700"; };
      "/state/log/sshd" = { mode = "700"; };
      "/state/log/net-eth0" = { mode = "700"; };
      "/state/log/nix-daemon" = { mode = "700"; };
      "/state/log/getty-tty1" = { mode = "700"; };
      "/state/identity/sshd" = { mode = "700"; };
    };
    exec = let path = pkgs.lib.makeBinPath (with pkgs; [ busybox dropbear ]);
    in pkgs.writeScript "post-install" ''
      #!${pkgs.busybox}/bin/sh -eu
      export PATH=${path}
      if ! [ -f /state/identity/sshd/ed25519 ] ; then
        dropbearkey -t ed25519 -f /state/identity/sshd/ed25519
      fi
    '';
  };
in nixsys.override {
  manifest = writeText "manifest.json" (builtins.toJSON manifest);
}
