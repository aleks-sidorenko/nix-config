{ inputs, ... }:
{
  flake-file.inputs.nix-routeros = {
    url = "github:aleks-sidorenko/nix-routeros/v2.0.0";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.terranix.follows = "terranix";
  };

  den.aspects.infra.routeros.terranix =
    { stack, ... }:
    {
      imports = [ inputs.nix-routeros.terranixModules.default ];

      _meta.secrets.TF_VAR_routeros_password = {
        file = "${stack.dir}/secrets.yaml";
        key = "router-api-password";
      };
    };
}
