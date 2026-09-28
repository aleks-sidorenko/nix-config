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

      # Host identity lives on the tailnet, so membership is part of the base
      # system rather than a property of any one role. mkDefault so a host can
      # opt out.
      services.networking.tailscale = {
        enable = mkDefault true;
        # Joining is unattended everywhere: a host that cannot decrypt the key
        # fails activation, which is why this is safe only while every host
        # with this role is a recipient of its platform's secrets file.
        authKeyFromSecret = mkDefault true;
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
        # DNS search domains (tailnet + lan); MagicDNS resolves hosts, not /etc/hosts
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
    };
  };
}
