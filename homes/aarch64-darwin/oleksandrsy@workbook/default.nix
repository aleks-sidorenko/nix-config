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

    # Use Homebrew claude-code for latest version
    development.ai.claude-code.install = mkForce false;

    user = {
      enable = true;
      name = mkForce "oleksandrsy";
    };
  };

  home.stateVersion = "25.05";
}
