{
  pkgs,
  lib,
  ...
}:
{
  plugins = {
    # General LSP configuration and keymaps
    lsp-lines = {
      enable = true;
    };
    lsp-format = {
      enable = true;
    };
    helm = {
      enable = true;
    };
    lsp = {
      enable = true;
      inlayHints = true;
      servers = {
        # General purpose LSPs (always enabled)
        html = {
          enable = true;
        };
        lua_ls = {
          enable = true;
        };
        nil_ls = {
          enable = true;
        };
        marksman = {
          enable = true;
        };
        terraformls = {
          enable = true;
        };
        jsonls = {
          enable = true;
        };
        helm_ls = {
          enable = true;
          extraOptions = {
            settings = {
              "helm_ls" = {
                yamlls = {
                  path = "${pkgs.yaml-language-server}/bin/yaml-language-server";
                };
              };
            };
          };
        };
        yamlls = {
          enable = true;
          extraOptions = {
            settings = {
              yaml = {
                schemas = {
                  kubernetes = "'*.yaml";
                  "http://json.schemastore.org/github-workflow" = ".github/workflows/*";
                  "http://json.schemastore.org/github-action" = ".github/action.{yml,yaml}";
                  "http://json.schemastore.org/ansible-stable-2.9" = "roles/tasks/*.{yml,yaml}";
                  "http://json.schemastore.org/kustomization" = "kustomization.{yml,yaml}";
                  "http://json.schemastore.org/ansible-playbook" = "*play*.{yml,yaml}";
                  "http://json.schemastore.org/chart" = "Chart.{yml,yaml}";
                  "https://json.schemastore.org/dependabot-v2" = ".github/dependabot.{yml,yaml}";
                  "https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json" =
                    "*docker-compose*.{yml,yaml}";
                  "https://raw.githubusercontent.com/argoproj/argo-workflows/master/api/jsonschema/schema.json" =
                    "*flow*.{yml,yaml}";
                };
              };
            };
          };
        };

        # Language-specific LSPs are in separate language files
      };

      keymaps = {
        silent = true;
        lspBuf = {
          gd = {
            action = "definition";
            desc = "Goto Definition";
          };
          gr = {
            action = "references";
            desc = "Goto References";
          };
          gD = {
            action = "declaration";
            desc = "Goto Declaration";
          };
          gI = {
            action = "implementation";
            desc = "Goto Implementation";
          };
          gT = {
            action = "type_definition";
            desc = "Type Definition";
          };
          gh = {
            action = "hover";
            desc = "Hover";
          };
          "<leader>cw" = {
            action = "workspace_symbol";
            desc = "Workspace Symbol";
          };
          "<leader>cr" = {
            action = "rename";
            desc = "Rename";
          };
        };
        diagnostic = {
          "<leader>cd" = {
            action = "open_float";
            desc = "Line Diagnostics";
          };
          "[d" = {
            action = "goto_next";
            desc = "Next Diagnostic";
          };
          "]d" = {
            action = "goto_prev";
            desc = "Previous Diagnostic";
          };
        };
      };
    };

    # LSP progress UI
    fidget = {
      enable = true;
      settings = {
        logger = {
          level = "warn";
          float_precision = 1.0e-2;
        };
        progress = {
          poll_rate = 0;
          suppress_on_insert = true;
          ignore_done_already = false;
          ignore_empty_message = false;
          clear_on_detach = ''
            function(client_id)
              local client = vim.lsp.get_client_by_id(client_id)
              return client and client.name or nil
            end
          '';
          notification_group = ''
            function(msg) return msg.lsp_client.name end
          '';
          ignore = [ ];
          lsp = {
            progress_ringbuf_size = 0;
          };
          display = {
            render_limit = 16;
            done_ttl = 3;
            done_icon = "✔";
            done_style = "Constant";
            progress_ttl = 10;
            progress_icon = {
              pattern = "dots";
              period = 1;
            };
            progress_style = "WarningMsg";
            group_style = "Title";
            icon_style = "Question";
            priority = 30;
            skip_history = true;
            format_message = ''
              require ("fidget.progress.display").default_format_message
            '';
            format_annote = ''
              function (msg) return msg.title end
            '';
            format_group_name = ''
              function (group) return tostring (group) end
            '';
            overrides = {
              rust_analyzer = {
                name = "rust-analyzer";
              };
            };
          };
        };
        notification = {
          poll_rate = 10;
          filter = "info";
          history_size = 128;
          override_vim_notify = true;
          redirect = {
            __raw = ''
              function(msg, level, opts)
                if opts and opts.on_open then
                  return require("fidget.integration.nvim-notify").delegate(msg, level, opts)
                end
              end
            '';
          };
          configs = {
            default = {
              name = "Notifications";
              icon = "󰏪";
              group = "Notifications";
              annote = true;
              debug = false;
              debug_rate = 0.25;
            };
          };
          window = {
            normal_hl = "Comment";
            winblend = 0;
            border = "none";
            zindex = 45;
            max_width = 0;
            max_height = 0;
            x_padding = 1;
            y_padding = 0;
            align = "bottom";
            relative = "editor";
          };
          view = {
            stack_upwards = true;
            icon_separator = " ";
            group_separator = "---";
            group_separator_hl = "Comment";
          };
        };
      };
    };

    # Formatting configuration
    conform-nvim = {
      enable = true;
      settings = {
        format_on_save = ''
          function(bufnr)
            if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
              return
            end

            if slow_format_filetypes[vim.bo[bufnr].filetype] then
              return
            end

            local function on_format(err)
              if err and err:match("timeout$") then
                slow_format_filetypes[vim.bo[bufnr].filetype] = true
              end
            end

            return { timeout_ms = 200, lsp_fallback = true }, on_format
           end
        '';

        format_after_save = ''
          function(bufnr)
            if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
              return
            end

            if not slow_format_filetypes[vim.bo[bufnr].filetype] then
              return
            end

            return { lsp_fallback = true }
          end
        '';
        notify_on_error = true;
        formatters_by_ft = {
          # Language-specific formatters are in separate language files
          # General purpose formatters only
          html = {
            __unkeyed-1 = "prettierd";
            __unkeyed-2 = "prettier";
            stop_after_first = true;
          };
          css = {
            __unkeyed-1 = "prettierd";
            __unkeyed-2 = "prettier";
            stop_after_first = true;
          };
          lua = [ "stylua" ];
          nix = [ "nixfmt-rfc-style" ];
          markdown = {
            __unkeyed-1 = "prettierd";
            __unkeyed-2 = "prettier";
            stop_after_first = true;
          };
          yaml = {
            __unkeyed-1 = "prettierd";
            __unkeyed-2 = "prettier";
            stop_after_first = true;
          };
          terraform = [ "terraform_fmt" ];
          bicep = [ "bicep" ];
          bash = [
            "shellcheck"
            "shellharden"
            "shfmt"
          ];
          json = [ "jq" ];
          "_" = [ "trim_whitespace" ];
        };

        formatters = {
          black = {
            command = "${lib.getExe pkgs.black}";
          };
          isort = {
            command = "${lib.getExe pkgs.isort}";
          };
          nixfmt-rfc-style = {
            command = "${lib.getExe pkgs.nixfmt-rfc-style}";
          };
          alejandra = {
            command = "${lib.getExe pkgs.alejandra}";
          };
          jq = {
            command = "${lib.getExe pkgs.jq}";
          };
          prettierd = {
            command = "${lib.getExe pkgs.prettierd}";
          };
          stylua = {
            command = "${lib.getExe pkgs.stylua}";
          };
          shellcheck = {
            command = "${lib.getExe pkgs.shellcheck}";
          };
          shfmt = {
            command = "${lib.getExe pkgs.shfmt}";
          };
          shellharden = {
            command = "${lib.getExe pkgs.shellharden}";
          };
          bicep = {
            command = "${lib.getExe pkgs.bicep}";
          };
        };
      };
    };
  };

  extraPlugins = with pkgs.vimPlugins; [
    ansible-vim
  ];

  extraConfigLuaPre = ''
    local slow_format_filetypes = {}

    vim.api.nvim_create_user_command("FormatDisable", function(args)
       if args.bang then
        -- FormatDisable! will disable formatting just for this buffer
        vim.b.disable_autoformat = true
      else
        vim.g.disable_autoformat = true
      end
    end, {
      desc = "Disable autoformat-on-save",
      bang = true,
    })
    vim.api.nvim_create_user_command("FormatEnable", function()
      vim.b.disable_autoformat = false
      vim.g.disable_autoformat = false
    end, {
      desc = "Re-enable autoformat-on-save",
    })
    vim.api.nvim_create_user_command("FormatToggle", function(args)
      if args.bang then
        -- Toggle formatting for current buffer
        vim.b.disable_autoformat = not vim.b.disable_autoformat
      else
        -- Toggle formatting globally
        vim.g.disable_autoformat = not vim.g.disable_autoformat
      end
    end, {
      desc = "Toggle autoformat-on-save",
      bang = true,
    })
  '';

  extraConfigLua = ''
    local _border = "rounded"

    vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
      vim.lsp.handlers.hover, {
        border = _border
      }
    )

    vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
      vim.lsp.handlers.signature_help, {
        border = _border
      }
    )

    vim.diagnostic.config{
      float={border=_border}
    };

    require('lspconfig.ui.windows').default_options = {
      border = _border
    }
  '';
}
