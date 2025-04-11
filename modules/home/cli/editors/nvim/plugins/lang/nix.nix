{
  pkgs,
  config,
  namespace,
  ...
}:
let
  flake = config.home.sessionVariables.FLAKE;
  user = config.home.username;

  hostCfg = "desktop";
  homeCfg = "${user}@${hostCfg}";
in
{
  programs.nixvim = {
    files = {
      "ftplugin/nix.lua" = {
        opts = {
          expandtab = true;
          shiftwidth = 2;
          tabstop = 2;
        };
      };
    };

    plugins = {
      nix.enable = true;
      hmts.enable = true;
      nix-develop.enable = true;

      conform-nvim = {
        settings = {
          formatters_by_ft = {
            nix = [ "nixfmt" ];
          };
          formatters = {
            nixfmt = {
              command = "${pkgs.nixfmt-rfc-style}/bin/nixfmt-rfc-style";
            };
          };
        };
      };

      lint = {
        lintersByFt = {
          nix = [ "statix" ];
        };
        linters = {
          statix = {
            cmd = "${pkgs.statix}/bin/statix";
          };
        };
      };

      # lsp.servers.nil-ls = {
      #   enable = true;
      # };
      #
      lsp.servers.nixd = {
        enable = true;
        extraOptions.settings = {
          nixd = {
            nixpkgs = {
              expr = "import <nixpkgs> { }";
            };
            options = {
              nixos = {
                expr = ''(builtins.getFlake "${flake}").nixosConfigurations.${hostCfg}.options'';
              };
              home_manager = {
                expr = ''(builtins.getFlake "${flake}").homeConfigurations."${homeCfg}".options'';
              };
              flake_parts = {
                expr = ''let flake = builtins.getFlake ("${flake}"); in flake.debug.options // flake.currentSystem.options'';
              };
            };
          };
        };
      };
    };

    extraConfigVim = ''
      au BufRead,BufNewFile flake.lock setf json
    '';
  };
}
