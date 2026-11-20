{ den, ... }:
{
  den.aspects.gui.chrome = {
    includes = [
      (den.batteries.unfree [ "google-chrome" ])
      den.aspects.security.pass
    ];

    homeManager =
      { pkgs, ... }:
      {
        programs = {
          browserpass.enable = true;
          google-chrome = {
            enable = true;
            package = pkgs.google-chrome;
            commandLineArgs = [
              "--enable-logging=stderr"
              "--v=1"
            ];
          };
        };
      };

    darwin =
      {
        config,
        host,
        lib,
        ...
      }:
      {
        # Module order between aspects is not include order, so the slot is explicit:
        # after the terminal's default-order tile, before the mkAfter ones.
        system.defaults.dock.persistent-apps = lib.mkOrder 1100 [
          "${config.users.users.${host.primaryUser}.home}/Applications/Home Manager Apps/Google Chrome.app"
        ];
      };
  };
}
