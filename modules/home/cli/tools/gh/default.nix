{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.tools.gh;
  sopsEnabled = config.${namespace}.security.sops.enable;
  secretEnabled = sopsEnabled && cfg.githubToken;
in
{
  options.${namespace}.cli.tools.gh = with types; {
    enable = mkBoolOpt false "Whether or not to enable GitHub CLI";
    githubToken = mkBoolOpt false "Whether to set GITHUB_TOKEN from sops secret";
  };

  config = mkIf cfg.enable {
    programs.gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
      };
    };

    sops.secrets."github-token" = mkIf secretEnabled {
      sopsFile = ../../../secrets.yaml;
    };

    home.sessionVariables = mkIf secretEnabled {
      GITHUB_TOKEN = "$(cat ${config.sops.secrets."github-token".path})";
    };
  };
}
