{ config, ... }:
let
  c =
    (config.builders.nixos "x86_64-linux" {
      imports = [ config.flake.modules.nixos.fs ];
      system.stateVersion = "26.05";
    }).config;
in
{
  flake.modules.nixos.fs = {
    boot.kernel.sysctl = {
      "fs.file-max" = 524288;
      "fs.inotify.max_user_watches" = 524288;
      "fs.inotify.max_user_instances" = 256;
    };
  };

  evalTests = {
    fs-inotify-watches = {
      expr = c.boot.kernel.sysctl."fs.inotify.max_user_watches";
      expected = 524288;
    };
  };
}
