{ config, lib, ... }:
let
  secrets.TF_VAR_github_token = {
    file = import ./_secrets.nix;
    key = "github-token";
  };
in
{
  den.aspects.infra.github = {
    terranix =
      { stack, ... }:
      {
        terraform.required_providers.github = {
          source = "integrations/github";
          version = "~> 6.6";
        };

        variable.github_token = {
          type = "string";
          sensitive = true;
        };

        provider.github = {
          # The identity's first account is the one that owns repositories.
          owner = lib.head stack.identity.git.githubAccounts;
          token = "\${var.github_token}";
        };

        # Shared by every stack that manages the account, so stored once.
        _meta = { inherit secrets; };
      };
  };

  evalTests.infra-github-secrets = {
    expr = lib.unique (
      lib.mapAttrsToList (_: stack: lib.intersectAttrs secrets stack.meta.secrets) (
        lib.filterAttrs (_: stack: stack.meta.secrets ? TF_VAR_github_token) config.infraStacks
      )
    );
    expected = [
      {
        TF_VAR_github_token = {
          file = "infra/secrets.yaml";
          key = "github-token";
        };
      }
    ];
  };
}
