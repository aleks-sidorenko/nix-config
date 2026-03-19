{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  # TODO - replace with ${namespace} once this is fixed https://github.com/snowfallorg/lib/issues/142
  nix-config = {
    roles.work = enabled;

    user = {
      enable = true;
      name = mkForce "oleksandrsy";
    };
  };

  home.stateVersion = "25.05";
}
