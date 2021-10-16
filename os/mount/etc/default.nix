{ stdenv, writeScript, busybox, writeText, cacert, iana-etc, mk-passwd }:
let
  dropbox = part: "https://www.dropbox.com/s/${part}?dl=1";
  text = writeText "source.txt";
  usersh = writeScript "usersh" ''
    #!${busybox}/bin/sh
    test -t 0 || exec /bin/sh "$@"
    test -x ~/bin/sh  && exec ~/bin/sh "$@"
    exec /bin/sh
  '';

  passwd = stdenv.mkDerivation {
    name = "passwd";
    src = ./passwd.json;
    outputs = [ "out" "passwd" "group" ];
    dontUnpack = true;
    buildInputs = [ mk-passwd ];
    installPhase = ''
      substituteAll $src passwd.json
      mk-passwd < passwd.json --json $out --passwd $passwd --group $group
    '';

    inherit usersh;
  };

  hosts = stdenv.mkDerivation {
    name = "hosts.txt";
    src = builtins.fetchurl {
      url = dropbox "5ijevtagpidy2et/hosts-2020-12-13.gz";
      sha256 = "0k7k09gai1w107mq5x20yld5cd0l1xk2bw1cg2wxmn8mi4ga4rxa";
    };
    dontUnpack = true;
    installPhase = ''
      gzip -d < $src > $out
    '';
  };

  manifest = {
    copy = {
      "/etc/hosts" = {
        path = hosts;
        mode = "0444";
      };
      "/etc/resolv.conf" = {
        path = text "nameserver 1.1.1.1";
        mode = "0444";
      };
      "/etc/ssl/certs/ca-certificates.crt" = {
        path = "${cacert}/etc/ssl/certs/ca-bundle.crt";
        mode = "0444";
      };
      "/etc/protocols" = {
        path = "${iana-etc}/etc/protocols";
        mode = "0444";
      };
      "/etc/services" = {
        path = "${iana-etc}/etc/services";
        mode = "0444";
      };
      "/etc/passwd" = {
        path = passwd.passwd;
        mode = "0444";
      };
      "/etc/group" = {
        path = passwd.group;
        mode = "0444";
      };
    };
  };

in writeText "manifest.json" (builtins.toJSON manifest)
