{ writeText, doas, cwrap }:

let
  doas' = doas.override { withPAM = false; };
  manifest.copy = {
    "/suid/doas" = {
      path = cwrap "${doas'}/bin/doas";
      mode = "04555";
    };
    "/etc/doas.conf" = {
      path = writeText "doas.conf" ''
        permit nopass keepenv user
      '';
      mode = "0444";
    };
  };
in writeText "manifest-doas.json" (builtins.toJSON manifest)
