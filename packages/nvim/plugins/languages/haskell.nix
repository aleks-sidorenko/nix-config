{
  pkgs,
  lib,
  config,
  ...
}:
lib.mkIf config.development.haskell.enable {
  # Haskell Language Server with advanced tooling
  plugins.haskell-tools = {
    enable = true;

    settings = {
      hls = {
        on_attach = ''
          function(client, bufnr)
            local opts = { noremap = true, silent = true, buffer = bufnr }
            -- Hoogle search
            vim.keymap.set('n', '<leader>hs', vim.lsp.buf.hover, opts)
            vim.keymap.set('n', '<leader>hh', require('haskell-tools').hoogle.hoogle_signature, opts)
            -- Repl
            vim.keymap.set('n', '<leader>hr', require('haskell-tools').repl.toggle, opts)
            vim.keymap.set('n', '<leader>hf', function()
              require('haskell-tools').repl.toggle(vim.api.nvim_buf_get_name(0))
            end, opts)
            vim.keymap.set('n', '<leader>hq', require('haskell-tools').repl.quit, opts)
          end
        '';
        default_settings = {
          haskell-language-server = {
            formattingProvider = "ormolu";
            checkProject = true;
          };
        };
      };

      tools = {
        codeLens = {
          autoRefresh = true;
        };
        hoogle = {
          mode = "auto";
        };
        hover = {
          enable = true;
          border = "rounded";
        };
        repl = {
          handler = "builtin";
          builtin = {
            create_repl_window = ''
              function(view)
                return view.create_repl_split({ size = vim.o.lines / 3 })
              end
            '';
          };
        };
        tags = {
          enable = true;
          package = pkgs.haskellPackages.fast-tags;
        };
      };
    };
  };

  # Formatting
  plugins.conform-nvim.settings.formatters_by_ft.haskell = [ "ormolu" ];

  # Toolchain and tools
  extraPackages = with pkgs; [
    # Haskell toolchain
    ghc
    cabal-install
    stack

    # Formatters
    ormolu
    stylish-haskell

    # Additional tools
    haskellPackages.hoogle
    haskellPackages.fast-tags
    haskellPackages.hlint
  ];
}
