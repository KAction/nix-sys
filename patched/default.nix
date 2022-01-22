let
  patch = drv: more:
    drv.overrideAttrs (old: { patches = (old.patches or [ ]) ++ more; });

in self: super: { djbdns = patch super.djbdns [ ./djbdns/hosts.patch ]; }
