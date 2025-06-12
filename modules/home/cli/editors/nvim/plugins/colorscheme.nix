let
in
{
  programs.nixvim = {
    colorschemes.catppuccin = {
      enable = true;
      settings = {
        flavour = "mocha";
        integrations = {
          cmp = true;
          dashboard = true;
          dap = {
            enable_ui = true;
            enabled = true;
          };
          gitsigns = true;
          illuminate.enabled = true;
          flash = true;
          indent_blankline.enabled = true;
          mini.enabled = true;
          navic.enabled = true;
          telescope.enabled = true;
        };
      };
    };

    extraConfigLua = ''
      require("dap")

      local sign = vim.fn.sign_define

      sign("DapBreakpoint", { text = "●", texthl = "DapBreakpoint", linehl = "", numhl = ""})
      sign("DapBreakpointCondition", { text = "●", texthl = "DapBreakpointCondition", linehl = "", numhl = ""})
      sign("DapLogPoint", { text = "◆", texthl = "DapLogPoint", linehl = "", numhl = ""})
      sign('DapStopped', { text='', texthl='DapStopped', linehl='DapStopped', numhl= 'DapStopped' })
    '';
  };
}
