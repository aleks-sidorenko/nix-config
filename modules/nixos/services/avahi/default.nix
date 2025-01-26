{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.services.nix-config.avahi;
in {
  options.services.nix-config.avahi = {
    enable = mkEnableOption "Enable The avahi service";
  };

  config = mkIf cfg.enable {
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        domain = true;
        hinfo = true;
        userServices = true;
        workstation = true;
      };
    };
  };
}
