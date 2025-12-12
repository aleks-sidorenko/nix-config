{
  autoGroups = {
    highlight_yank = { };
    vim_enter = { };
    indentscope = { };
    restore_cursor = { };
  };

  autoCmd = [
    {
      group = "highlight_yank";
      event = [ "TextYankPost" ];
      pattern = "*";
      callback = {
        __raw = ''
          function()
            vim.highlight.on_yank()
          end
        '';
      };
    }
    {
      group = "vim_enter";
      event = [ "VimEnter" ];
      pattern = "*";
      callback = {
        __raw = ''
          function()
            vim.cmd('Startup')
          end
        '';
      };
    }
    {
      group = "indentscope";
      event = [ "FileType" ];
      pattern = [
        "help"
        "Startup"
        "startup"
        "neo-tree"
        "Trouble"
        "trouble"
        "notify"
      ];
      callback = {
        __raw = ''
          function()
            vim.b.miniindentscope_disable = true
          end
        '';
      };
    }
    ## from NVChad https://nvchad.com/docs/recipes (this autocmd will restore the cursor position when opening a file)
    {
      group = "restore_cursor";
      event = [ "BufReadPost" ];
      pattern = "*";
      callback = {
        __raw = ''
          function()
            local mark = vim.api.nvim_buf_get_mark(0, '"')
            local line_count = vim.api.nvim_buf_line_count(0)
            local ft = vim.bo.filetype
            if mark[1] > 1
              and mark[1] <= line_count
              and ft ~= "commit"
              and ft ~= "xxd"
              and ft ~= "gitrebase"
            then
              pcall(vim.api.nvim_win_set_cursor, 0, mark)
            end
          end
        '';
      };
    }
  ];
}
