{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.common;
in
{
  options.${namespace}.roles.common = with types; {
    enable = mkEnableOption "Enable common darwin configuration";
    homebrew = {
      taps = mkOpt (listOf str) [ ] "Additional Homebrew taps";
      brews = mkOpt (listOf str) [ ] "Additional Homebrew formulae";
      casks = mkOpt (listOf str) [ ] "Additional Homebrew casks";
    };
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      security = {
        pam.enable = true;
        sops.enable = true;
        ssh.enable = true;
      };

      system = {
        nix = {
          enable = true;
          githubAuth = true;
        };
        # Darwin (macOS) UI preferences (MDM may override some)
        defaults.enable = true;
        # Raise kernel file descriptor limits (default ~49152 triggers ENFILE)
        fs.enable = true;
        # /etc/hosts with local network entries
        networking.enable = true;

        # Homebrew for CLI tools and GUI apps
        homebrew = {
          enable = true;
          inherit (cfg.homebrew) taps;
          inherit (cfg.homebrew) brews;
          inherit (cfg.homebrew) casks;
        };
      };

      cli = {
        shells.fish = {
          enable = true;
          default = true;
        };

        tools.nh = {
          enable = true;
          clean.enable = true;
        };
      };

      user.enable = true;
    };
  };
}
