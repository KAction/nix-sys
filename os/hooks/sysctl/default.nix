{ writeText, writeScript, execline, busybox }:
let
  m.copy."/etc/hooks/000-sysctl" = {
    path = writeScript "hooks-sysctl" ''
      #!${execline}/bin/execlineb -P
      ${busybox}/bin/sysctl -qpw
    '';
    mode = "0555";
  };
  m.copy."/etc/sysctl.conf" = {
    path = writeText "sysctl.conf" ''
      fs.inotify.max_user_watches = 3200000
    '';
    mode = "0444";
  };
in writeText "manifest.json" (builtins.toJSON m)
