{ lib, ... }:
{
  den.aspects.storage.impermanence.settings.root = lib.mkOption {
    type = lib.types.str;
    default = "/persist";
    description = "Where impermanent hosts keep state that survives a reboot.";
  };
}
