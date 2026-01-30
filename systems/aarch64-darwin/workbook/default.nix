{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  ${namespace} = {
    # Use work role (includes common + homebrew + defaults)
    roles.work = {
      enable = true;
    };

    # Override user name for this machine
    user.name = "oleksandrsy";
  };

  system.stateVersion = "25.05";
}
