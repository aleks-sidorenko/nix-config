{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.tools.atuin;

  atuin-export-fish = pkgs.buildGoModule rec {
    pname = "atuin-export-fish-history";
    version = "0.1.0";

    src = pkgs.fetchFromGitLab {
      owner = "hmajid2301";
      repo = pname;
      rev = "v${version}";
      sha256 = "sha256-2egZYLnaekcYm2IzPdWAluAZogdi4Nf/oXWLw8+AnMk=";
    };

    vendorHash = "sha256-hLEmRq7Iw0hHEAla0Ehwk1EfmpBv6ddBuYtq12XdhVc=";

    ldflags = [
      "-s"
      "-w"
    ];
  };
in
{
  options.${namespace}.cli.tools.atuin = with types; {
    enable = mkBoolOpt false "Whether or not to enable atuin";
  };

  config = mkIf cfg.enable {
    home.packages = [ atuin-export-fish ];

    programs.atuin = {
      enable = true;
      flags = [
        "--disable-up-arrow"
        "--disable-ctrl-r"
      ];

      settings = {
        auto_sync = true;
        sync_frequency = "5m";
        sync_address = "https://api.atuin.sh";
        search_mode = "prefix";

      };
    };

  };
}
