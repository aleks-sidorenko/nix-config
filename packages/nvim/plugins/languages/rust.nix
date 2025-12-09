{
  pkgs,
  lib,
  config,
  ...
}:
lib.mkIf config.development.rust.enable {
  # Rust analyzer with enhanced tooling
  plugins.rustaceanvim = {
    enable = true;

    settings = {
      server = {
        default_settings = {
          rust-analyzer = {
            cargo = {
              allFeatures = true;
              loadOutDirsFromCheck = true;
              buildScripts = {
                enable = true;
              };
            };
            checkOnSave = {
              command = "clippy";
            };
            procMacro = {
              enable = true;
              ignored = {
                leptos_macro = [
                  "component"
                  "server"
                ];
              };
            };
            inlayHints = {
              bindingModeHints = {
                enable = false;
              };
              chainingHints = {
                enable = true;
              };
              closingBraceHints = {
                enable = true;
                minLines = 25;
              };
              closureReturnTypeHints = {
                enable = "never";
              };
              lifetimeElisionHints = {
                enable = "never";
                useParameterNames = false;
              };
              maxLength = 25;
              parameterHints = {
                enable = true;
              };
              reborrowHints = {
                enable = "never";
              };
              renderColons = true;
              typeHints = {
                enable = true;
                hideClosureInitialization = false;
                hideNamedConstructor = false;
              };
            };
          };
        };
      };

      dap = {
        adapter = {
          type = "executable";
          command = "${pkgs.lldb}/bin/lldb-vscode";
          name = "rt_lldb";
        };
      };
    };
  };

  # Formatting
  plugins.conform-nvim.settings.formatters_by_ft.rust = [ "rustfmt" ];

  # Rust toolchain
  extraPackages = with pkgs; [
    cargo
    rustc
    clippy
    rustfmt
  ];
}
