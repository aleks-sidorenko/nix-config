{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.work;
in
{
  options.${namespace}.roles.work = {
    enable = mkEnableOption "Enable work machine configuration";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isDarwin;
        message = "The work role is only supported on Darwin (macOS) systems";
      }
    ];

    ${namespace} = {
      roles = {
        common = enabled; # Reuse common CLI tools

        development = {
          enable = true;
          ai = {
            claude-code = true;
            copilot = false;
          };
          languages = {
            scala = true;
            java = true;
          };
          editors = {
            code = true;
            cursor = true;
            idea = true;
          };
          build = {
            bazel = true;
          };
          database = {
            mysql = true;
          };
        };
      };

      cli = {
        tools = {
          k8s.enable = false;
        };
      };

      browsers = {
        chrome.enable = true;
      };
    };

  };
}
