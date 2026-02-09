{
  lib,
  namespace,
  ...
}:
rec {

  # Returns the appropriate flake directory path based on the context:
  # - For home-manager modules: returns $HOME based path
  # - For NixOS modules: returns absolute path using user name from config
  # - For shells/other contexts: returns $HOME based path if no config provided
  flakeDir = config: toString (/. + "${lib.${namespace}.homeDir config}/.${namespace}");

  persistence = {

    # Returns the root path for persistent storage, null if disabled
    root =
      config:
      let
        cfg = config.${namespace}.disks.impermanence;
      in
      if cfg.enable then cfg.root else null;

    # Returns the persistence dirs if enabled or empty list if not
    dirs =
      config:
      let
        cfg = config.${namespace}.disks.impermanence;
      in
      if cfg.enable then [ cfg.root ] else [ ];

    # Returns the path to a persistent directory based on whether opt-in persistence is enabled
    resolve =
      config: path:
      let
        cfg = config.${namespace}.disks.impermanence;
      in
      "${lib.optionalString cfg.enable cfg.root}${path}";

  };

  homebrew = {
    path = "/opt/homebrew";
    binPath = "${homebrew.path}/bin";
    getExe = name: "${homebrew.binPath}/${name}";
  };

}
