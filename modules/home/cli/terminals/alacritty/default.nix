{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.terminals.alacritty;
in
{
  options.${namespace}.cli.terminals.alacritty = with types; {
    enable = mkEnableOption "Enable alacritty terminal emulator.";
    default = mkBoolOpt false "Whether or not to use alacritty as the default terminal.";
  };

  config = mkIf cfg.enable {
    ${namespace}.cli.terminals.default = mkIf cfg.default {
      enable = true;
      name = "alacritty";
      package = pkgs.alacritty;
    };

    programs.alacritty = {
      enable = true;

      settings = {
        shell = {
          program = "fish";
        };

        window = {
          padding = {
            x = 30;
            y = 30;
          };
          decorations = "none";
        };

        selection = {
          save_to_clipboard = true;
        };

        mouse_bindings = [
          {
            mouse = "Right";
            action = "Paste";
          }
        ];

        env = {
          TERM = "xterm-256color";
        };
      };
    };
  };
}
