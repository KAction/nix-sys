{ runCommand, openssl, stdenv, writeScript, busybox, writeText, cacert, iana-etc
, mk-passwd }:
let
  dropbox = part: "https://www.dropbox.com/s/${part}?dl=1";
  text = writeText "source.txt";
  usersh = writeScript "usersh" ''
    #!${busybox}/bin/sh
    test -t 0 || exec /bin/sh "$@"
    test -x ~/bin/sh  && exec ~/bin/sh "$@"
    exec /bin/sh
  '';

  # This derivation generates self-signed certificate that will be added
  # into the bundle of trusted certficates. It allows me to mitm all own
  # connections without configuring every individual client.
  #
  # Derivation is deliberately non-deterministic, since I don't want
  # anybody else to get certificate that would allow launching real attack.
  # Non-deterministic certificates are considerer bad practices, clearly, but
  # I think it is okay in this case.
  #
  # mitmproxy does not support ed25519 certificates.
  mitm = stdenv.mkDerivation {
    name = "mitm";
    dontUnpack = true;
    buildInputs = [ openssl ];
    installPhase = ''
      mkdir -p $out
      openssl req -x509 -newkey rsa:2048  \
        -keyout $out/$name.key            \
        -out    $out/$name.crt            \
        -sha256                           \
        -nodes                            \
        -subj '/CN=mitmproxy@kaction.cc/' \
        -days 36500
    '';
  };

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

  manifest = {
    copy = {
      # nix-build gets upset if /etc/hosts is not present at all.
      "/etc/hosts" = {
        path = text "127.0.0.1 localhost";
        mode = "0444";
      };
      "/etc/mitm.pem" = {
        path = runCommand "mitm.pem" { } ''
          cat ${mitm}/mitm.crt ${mitm}/mitm.key > $out
        '';
        mode = "0444";
      };
      "/etc/resolv.conf" = {
        path = text "nameserver 127.0.0.3";
        mode = "0444";
      };
      "/etc/ssl/certs/ca-certificates.crt" = {
        path = runCommand "ca-certificates.crt" { } ''
          cat ${cacert}/etc/ssl/certs/ca-bundle.crt \
              ${mitm}/mitm.crt > $out
        '';
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
