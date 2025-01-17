{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.services.nix-config.ollama;
in {
  options.services.nix-config.ollama = {
    enable = mkEnableOption "Enable ollama and web ui";
  };

  config = mkIf cfg.enable {
    services.ollama = {
      enable = true;
    };

    services.open-webui = {
      enable = true;
      port = 8085;
    };
  };
}
