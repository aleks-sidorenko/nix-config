{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktops.aerospace;
in
{
  options.${namespace}.desktops.aerospace = with types; {
    enable = mkBoolOpt false "Enable AeroSpace tiling window manager";
  };

  config = mkIf cfg.enable {
    # Tap set directly via nix-darwin (${namespace}.system.homebrew does not expose taps)
    homebrew.taps = [ "nikitabobko/tap" ];
    ${namespace}.system.homebrew.casks = [
      "aerospace"
    ];
  };
}
