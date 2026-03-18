{
  config,
  lib,
  pkgs,
  ...
}:
{
  plugins = {
    claude-code = {
      inherit (config.ai.claude-code) enable;
      package = pkgs.vimPlugins.claude-code-nvim.overrideAttrs (_oldAttrs: {
        patches = [
          ./claude-code_unlist-buffer.patch
        ];
      });

      lazyLoad.enable = true;
      lazyLoad.settings.cmd = [
        "ClaudeCode"
        "ClaudeCodeContinue"
        "ClaudeCodeResume"
        "ClaudeCodeVerbose"
      ];

      settings = {
        window = {
          split_ratio = 0.3;
          position = "botright";
          enter_insert = true;
          hide_numbers = true;
          hide_signcolumn = true;
        };
        refresh = {
          enable = true;
          updatetime = 100;
          timer_interval = 1000;
          show_notifications = true;
        };
        git = {
          use_git_root = true;
        };
        command = "claude";
        keymaps = {
          toggle = {
            normal = "<C-;>";
            terminal = "<C-;>";
          };
          window_navigation = true;
          scrolling = true;
        };
      };
    };

    which-key.settings.spec = lib.optionals config.plugins.claude-code.enable [
      {
        __unkeyed-1 = "<leader>ac";
        group = "Claude Code";
        icon = "";
        mode = [
          "n"
          "v"
        ];
      }
    ];
  };

  keymaps = lib.mkIf config.plugins.claude-code.enable [
    {
      key = "<leader>act";
      action = "<cmd>ClaudeCode<CR>";
      options.desc = "Toggle Claude";
    }
    {
      key = "<leader>acc";
      action = "<cmd>ClaudeCodeContinue<CR>";
      options.desc = "Continue Claude";
    }
    {
      key = "<leader>acr";
      action = "<cmd>ClaudeCodeResume<CR>";
      options.desc = "Resume Claude";
    }
    {
      key = "<leader>acv";
      action = "<cmd>ClaudeCodeVerbose<CR>";
      options.desc = "Verbose Claude";
    }
  ];
}
