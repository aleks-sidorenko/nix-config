{
  pkgs,
  lib,
  config,
  ...
}:
lib.mkIf config.development.python.enable {
  # Python LSP
  plugins.lsp.servers.pyright = {
    enable = true;
  };

  # Python formatters
  plugins.conform-nvim.settings.formatters_by_ft.python = [
    "black"
    "isort"
  ];

  extraPackages = with pkgs; [
    black
    isort
  ];
}
