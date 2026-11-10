{
  flake.modules.nixos.fish =
    { pkgs, ... }:
    {
      programs.fish = {
        enable = true;
        vendor = {
          completions.enable = true;
          config.enable = true;
          functions.enable = true;
        };
      };

      users.defaultUserShell = pkgs.fish;
    };
}
