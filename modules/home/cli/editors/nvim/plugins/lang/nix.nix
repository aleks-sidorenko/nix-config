{
  pkgs,
  config,
  namespace,
  ...
}:
let
  flake = config.home.sessionVariables.FLAKE;

  hostCfg = "desktop";
  user = config.${namespace}.user.name;
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
            nix = [ "alejandra" ];
          };
          formatters = {
            alejandra = {
              command = "${pkgs.alejandra}/bin/alejandra";
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
