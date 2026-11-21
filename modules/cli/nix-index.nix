{ inputs, ... }:
{
  flake-file.inputs.nix-index-database = {
    url = "github:nix-community/nix-index-database";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.cli.nix-index.homeManager =
    { ... }:
    {
      imports = [ inputs.nix-index-database.homeModules.nix-index ];

      programs = {
        nix-index = {
          enable = true;
          enableBashIntegration = true;
        };
        nix-index-database.comma.enable = true;
      };
    };
}
