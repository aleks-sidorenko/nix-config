{
  den.aspects.cli.atuin.homeManager.programs.atuin = {
    enable = true;
    flags = [
      "--disable-up-arrow"
      "--disable-ctrl-r"
    ];
    settings = {
      auto_sync = true;
      sync_frequency = "5m";
      sync_address = "https://api.atuin.sh";
      search_mode = "prefix";
    };
  };
}
