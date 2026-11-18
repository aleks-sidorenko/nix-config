{ den, ... }:
{
  den.aspects.cli.fzf = {
    includes = [ den.aspects.system.stylix ];

    homeManager =
      { config, lib, ... }:
      let
        inherit (config.lib.stylix.colors.withHashtag)
          base00
          base02
          base05
          base06
          base08
          base0A
          base0E
          ;
      in
      {
        programs.fzf = {
          enable = true;
          # fzf-fish binds the keys itself.
          enableFishIntegration = false;
          colors = lib.mkForce {
            bg = base00;
            "bg+" = base02;
            fg = base05;
            "fg+" = base05;
            header = base0E;
            hl = base08;
            "hl+" = base08;
            info = base0A;
            marker = base06;
            pointer = base06;
            prompt = base0E;
            spinner = base06;
          };
        };
      };
  };
}
