{
  pkgs,
  lib,
  config,
  ...
}:
lib.mkIf config.development.typescript.enable {
  # TypeScript LSP
  plugins.lsp.servers.ts_ls = {
    enable = true;
  };

  # TypeScript/JavaScript formatters
  plugins.conform-nvim.settings.formatters_by_ft = {
    javascript = {
      __unkeyed-1 = "prettierd";
      __unkeyed-2 = "prettier";
      stop_after_first = true;
    };
    typescript = {
      __unkeyed-1 = "prettierd";
      __unkeyed-2 = "prettier";
      stop_after_first = true;
    };
  };

  extraPackages = with pkgs; [
    prettierd
    nodePackages.prettier
  ];
}
