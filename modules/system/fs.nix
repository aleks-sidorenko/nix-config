{ config, ... }:
let
  c = (config.builders.testNixos config.flake.modules.nixos.fs).config;
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
