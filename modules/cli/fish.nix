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
      # Remote tooling (nixos-anywhere, deploy-rs) runs POSIX shell commands as
      # root over SSH, which fish would reject.
      users.users.root.shell = pkgs.bashInteractive;
    };
}
