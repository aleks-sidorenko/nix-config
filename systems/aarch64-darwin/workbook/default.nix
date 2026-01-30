{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  ${namespace} = {
    # Use workstation role (includes common + homebrew + defaults)
    roles.workstation = {
      enable = true;
    };

    # Override user name for this machine
    user.name = "oleksandrsy";
  };

  system.stateVersion = 5;
}
