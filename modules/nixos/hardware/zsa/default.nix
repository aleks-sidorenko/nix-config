{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.hardware.zsa;
in
{
  options.${namespace}.hardware.zsa = with types; {
    enable = mkBoolOpt false "Enable ZSA Keyboard";
  };

  config = mkIf cfg.enable {
    hardware.keyboard.zsa.enable = true;
  };
}
