{
  lib,
  config,
  pkgs,
  inputs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.tools.nix-index;

  # nix-index-database only publishes prebuilt indexes for these systems;
  # x86_64-darwin was dropped upstream, so fall back to a DB-less nix-index there.
  hasPrebuiltDb = elem pkgs.stdenv.hostPlatform.system [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];
in
{
  options.${namespace}.cli.tools.nix-index = with types; {
    enable = mkBoolOpt false "Whether or not to nix index";
  };

  imports = with inputs; [
    nix-index-database.homeModules.nix-index
  ];

  config = mkIf cfg.enable {
    programs.nix-index = {
      enable = true;
      enableBashIntegration = true;
    }
    // optionalAttrs (!hasPrebuiltDb) {
      # No prebuilt index for this platform: use plain nix-index without the
      # bundled database and skip symlinking a database that does not exist.
      package = pkgs.nix-index;
      symlinkToCacheHome = false;
    };

    # comma-with-db needs the prebuilt (small) database, absent on unsupported platforms.
    programs.nix-index-database.comma.enable = hasPrebuiltDb;
  };
}
