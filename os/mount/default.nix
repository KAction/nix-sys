{ busybox, mk-passwd, writeText, nixFlakes, sinit, dropbear, buildEnv
, runCommand, cacert, iana-etc }:
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
  dropbox = part: "https://www.dropbox.com/s/${part}?dl=1";
  hosts = builtins.fetchurl {
    url = dropbox "5ijevtagpidy2et/hosts-2020-12-13.gz";
    sha256 = "0k7k09gai1w107mq5x20yld5cd0l1xk2bw1cg2wxmn8mi4ga4rxa";
  };
  passwd = runCommand "passwd" { config = ./passwd.json; } ''
    mkdir -p $out
    ${mk-passwd}/bin/mk-passwd < $config \
      --json $out/out.json \
      --passwd $out/passwd \
      --group $out/group
  '';
  resolv = writeText "resolv.conf" ''
    nameserver 1.1.1.1
  '';
  etc = runCommand "mount-etc" { } ''
    mkdir -p $out/ssl/certs

    ln -sf ${hosts}          $out/hosts
    ln -sf ${resolv}         $out/resolv.conf
    ln -sf ${passwd}/passwd  $out/passwd
    ln -sf ${passwd}/group   $out/group

    ln -sf ${iana-etc}/etc/protocols $out/protocols
    ln -sf ${iana-etc}/etc/services  $out/services

    ln -sf ${cacert}/etc/ssl/certs/ca-bundle.crt $out/ssl/certs/ca-certificates.crt
  '';

in {
  passwd = builtins.fromJSON (builtins.readFile "${passwd}/out.json");
  inherit bin usr etc;
}
