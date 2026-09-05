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
  cfg = config.${namespace}.roles.macbook;
in
{
  options.${namespace}.roles.macbook = {
    enable = mkEnableOption "Enable MacBook machine configuration";
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
            haskell = true;
            typescript = true;
          };

          testing = {
            testcontainers = false;
          };
        };

      };

      desktops.aerospace = enabled;

      cli.tools.git.lfs = true;

      browsers = {
        chrome.enable = true;
      };

    };

  };
}
