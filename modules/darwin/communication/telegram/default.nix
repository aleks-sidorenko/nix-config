{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.communication.telegram;
in
{
  options.${namespace}.communication.telegram = with types; {
    enable = mkBoolOpt false "Enable Telegram via Homebrew";
  };

  config = mkIf cfg.enable {
    ${namespace}.system.homebrew.casks = [
      "telegram"
    ];
  };
}
