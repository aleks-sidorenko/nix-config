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

  # Returns the executable path for a given package
  # Example: getExecPath pkgs.hello -> "/nix/store/...-hello/bin/hello"
  getExecPath = package: "${package}/bin/${package.pname}";

  persistence = {

    # Returns the root path for persistent storage
    getRoot = config: config.${namespace}.disks.impermanence.root;

    # Returns the path to a persistent directory based on whether opt-in persistence is enabled
    getPath =
      config: path:
      let
        cfg = config.${namespace}.disks.impermanence;
      in
      "${lib.optionalString cfg.enable cfg.root}${path}";

  };

}
