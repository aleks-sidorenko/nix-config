{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib.${namespace};
{

  # TODO - replace with ${namespace} once this is fixed https://github.com/snowfallorg/lib/issues/142
  nix-config = {
    roles = {
      desktop = enabled;
    };

    user = {
      enable = true;
    };

  };

  home.stateVersion = "25.05";
}
