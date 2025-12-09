{
  pkgs,
  lib,
  config,
  ...
}:
lib.mkIf config.development.go.enable {
  # Go LSP
  plugins.lsp.servers.gopls = {
    enable = true;
  };

  # Go formatters
  plugins.conform-nvim.settings.formatters_by_ft.go = [
    "gofmt"
    "goimports"
  ];

  extraPackages = with pkgs; [
    go
    gotools
  ];
}
