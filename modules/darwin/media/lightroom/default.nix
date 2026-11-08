{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.media.lightroom;
in
{
  options.${namespace}.media.lightroom = with types; {
    enable = mkBoolOpt false "Enable Adobe Lightroom via Homebrew";
  };

  config = mkIf cfg.enable {
    # Lightroom has no cask of its own; it is installed from inside Creative Cloud.
    ${namespace}.system.homebrew.casks = [
      "adobe-creative-cloud"
    ];
  };
}
