{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.browsers.chromium;
in
{
  options.${namespace}.browsers.chromium = with types; {
    enable = mkBoolOpt false "Enable Chromium via Homebrew";
  };

  config = mkIf cfg.enable {
    ${namespace}.system.homebrew.casks = [
      "ungoogled-chromium"
    ];
  };
}
