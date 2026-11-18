{
  den.aspects.cli.bat.homeManager =
    { pkgs, ... }:
    {
      programs.bat = {
        enable = true;
        extraPackages = builtins.attrValues {
          inherit (pkgs.bat-extras)
            batgrep
            batdiff
            batman
            ;
        };
      };

      home.sessionVariables.MANPAGER = "batman";
    };
}
