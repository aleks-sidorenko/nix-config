{ den, inputs, ... }:
{
  flake-file.inputs = {
    nix-nvim = {
      url = "github:aleks-sidorenko/nix-nvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim/nixos-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  den.aspects.cli.nvim = {
    includes = [ (den.batteries.unfree [ "cmp-emoji" ]) ];

    homeManager = {
      imports = [ inputs.nix-nvim.homeManagerModules.default ];

      programs.nix-nvim = {
        enable = true;
        theme = "catppuccin";
        development.typescript.enable = true;
        ai.claude-code.enable = true;
        # The CLI is installed separately; nixvim would otherwise build its own copy.
        extraConfig.dependencies.claude-code.enable = false;
      };

      home = {
        shellAliases.vimdiff = "nvim -d";
        sessionVariables = {
          VISUAL = "nvim";
          EDITOR = "nvim";
        };
      };
    };
  };
}
