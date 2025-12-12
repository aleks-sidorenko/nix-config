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
        on_attach = {
          __raw = ''
            function(client, bufnr, ht)
              local opts = { noremap = true, silent = true, buffer = bufnr }
              -- Hoogle search
              vim.keymap.set('n', '<leader>hh', vim.lsp.buf.hover, opts)
              vim.keymap.set('n', '<leader>hs', function()
                ht.hoogle.hoogle_signature()
              end, opts)
              -- Repl
              vim.keymap.set('n', '<leader>hr', function()
                ht.repl.toggle()
              end, opts)
              vim.keymap.set('n', '<leader>hf', function()
                ht.repl.toggle(vim.api.nvim_buf_get_name(0))
              end, opts)
              vim.keymap.set('n', '<leader>hq', function()
                ht.repl.quit()
              end, opts)
            end
          '';
        };

        default_settings = {
          haskell = {
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
        };

        repl = {
          handler = "builtin";
          builtin = {
            create_repl_window = {
              __raw = ''
                function(view)
                  return view.create_repl_split({ size = vim.o.lines / 3 })
                end
              '';
            };
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
    haskell-language-server
  ];
}
