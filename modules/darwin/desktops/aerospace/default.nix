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
    ${namespace}.system.homebrew = {
      taps = [ "nikitabobko/tap" ];
      casks = [ "aerospace" ];
    };
  };
}
