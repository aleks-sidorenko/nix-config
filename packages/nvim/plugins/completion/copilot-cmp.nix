_: {
  plugins.copilot-cmp.enable = true;

  plugins.copilot-lua = {
    enable = true;

    settings = {
      suggestion.enabled = false;
      panel.enabled = false;

      filetypes = {
        yaml = false;
        markdown = false;
        json = false;
        help = false;
        gitcommit = false;
        gitrebase = false;
      };
    };
  };
}
