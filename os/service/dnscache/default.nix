{ writeText, runit, make-service, stdenv, runCommand, tinycdb, djbdns, execline
}:
let
  dropbox = part: "https://www.dropbox.com/s/${part}?dl=1";
  hosts-txt = stdenv.mkDerivation {
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
  cc-cdb = stdenv.mkDerivation {
    name = "cc-cdb";
    buildInputs = [ tinycdb ];
    dontUnpack = true;
    installPhase = ''
      cc ${./cc-cdb.c} -lcdb -o $out
    '';
  };
  chroot = runCommand "dnscache.chroot" { inherit djbdns; } ''
    mkdir -p $out/ip $out/servers
    ${cc-cdb} < ${hosts-txt}
    mv hosts.cdb $out/hosts.cdb
    touch $out/ip/127
    # ipv4 only
    grep -v :: $djbdns/etc/dnsroots.global > $out/servers/@
  '';
in make-service {
  name = "dnscache";
  # todo: somehow fix mess with uid/gid
  runscript = ''
    redirfd -r 0 /dev/random
    export ROOT ${chroot}
    export IP 127.0.0.3
    export UID 500
    export GID 500
    export IPSEND 0.0.0.0
    export CACHESIZE 30000000
    exec dnscache
  '';
  dependencies = [ djbdns execline runit ];
}
