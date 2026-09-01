{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  ${namespace} = {
    roles.work = {
      enable = true;
    };

    users.alexander = {
      primary = true;
      admin = true;
      uid = 502;
    };

    system.networking = {
      knownNetworkServices = [
        "Wi-Fi"
      ];
    };
  };

  system.stateVersion = 5;
}
