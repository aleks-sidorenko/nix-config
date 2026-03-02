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

    # claude-code is installed via Homebrew on this host
    # because CrowdStrike blocks npm registry needed for the nix build
    roles.development.ai.claude-code = mkForce false;

    user = {
      enable = true;
      name = mkForce "oleksandrsy";
    };
  };

  home.stateVersion = "25.05";
}
