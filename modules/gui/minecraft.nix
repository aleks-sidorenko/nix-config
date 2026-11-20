{
  den.aspects.gui.minecraft.homeManager =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.prismlauncher ];
    };
}
