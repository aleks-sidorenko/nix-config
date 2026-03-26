{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  externalMonitor = "DELL U2419H";
in
{
  # TODO - replace with ${namespace} once this is fixed https://github.com/snowfallorg/lib/issues/142
  nix-config = {
    roles.work = enabled;

    desktops.aerospace.workspaceMonitorAssignment = genAttrs [ "6" "7" "8" "9" "10" ] (_: externalMonitor);

    user = {
      enable = true;
      name = mkForce "oleksandrsy";
    };
  };

  home.stateVersion = "25.05";
}
