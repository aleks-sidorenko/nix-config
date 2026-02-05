{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.communication.zoom;
in
{
  options.${namespace}.communication.zoom = with types; {
    enable = mkBoolOpt false "Enable Zoom via Homebrew";
  };

  config = mkIf cfg.enable {
    ${namespace}.system.homebrew.casks = [
      "zoom"
    ];
  };
}
