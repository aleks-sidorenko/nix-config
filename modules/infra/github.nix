{ config, lib, ... }:
let
  flakeChecks = [
    "Flake Check"
    "Check Formatting"
    "Build package"
  ];
  ruleset = config.infraStacks.github.config.resource.github_repository_ruleset;
in
{
  den.stacks.github.identity = "alexander";

  den.aspects.infra.github = {
    settings = {
      repos = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        default = {
          nix-config = [ "Check, install tests and server build" ];
          nix-routeros = [
            "Flake check"
            "Format"
            "Build example"
          ];
          nix-wallpapers = flakeChecks;
          nix-nvim = flakeChecks;
        };
        description = "Public repositories sharing the default-branch ruleset, each with the status checks a merge requires.";
      };
    };

    terranix =
      { stack, ... }:
      let
        inherit (stack.settings.infra.github) repos;
      in
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
          owner = lib.head stack.identity.git.githubAccounts;
          token = "\${var.github_token}";
        };

        _meta.secrets.TF_VAR_github_token = {
          file = import ./_secrets.nix;
          key = "github-token";
        };

        # Repository rulesets, not an account-wide one: those need a paid
        # plan, these are free on public repositories.
        resource.github_repository_ruleset = lib.mapAttrs (repository: checks: {
          inherit repository;
          name = "default-branch";
          target = "branch";
          enforcement = "active";

          conditions.ref_name = {
            include = [ "~DEFAULT_BRANCH" ];
            exclude = [ ];
          };

          rules = {
            non_fast_forward = true;
            deletion = true;
            required_linear_history = true;

            # A sole owner cannot approve their own pull request, so none is
            # required; the rule still forces every change through one.
            pull_request = {
              required_approving_review_count = 0;
              required_review_thread_resolution = true;
              allowed_merge_methods = [ "squash" ];
            };

            required_status_checks = {
              strict_required_status_checks_policy = false;
              required_check = map (context: { inherit context; }) checks;
            };
          };
        }) repos;

        # Adopted from a hand-made ruleset that targeted no branch.
        import = [
          {
            to = "github_repository_ruleset.nix-config";
            id = "nix-config:3313674";
          }
        ];
      };
  };

  evalTests = {
    infra-github-secrets = {
      expr = config.infraStacks.github.meta.secrets;
      expected = {
        TF_VAR_github_token = {
          file = "infra/secrets.yaml";
          key = "github-token";
        };
        TF_VAR_state_passphrase = {
          file = "infra/github/secrets.yaml";
          key = "state-passphrase";
        };
      };
    };
    infra-github-owner = {
      expr = config.infraStacks.github.config.provider.github.owner;
      expected = "aleks-sidorenko";
    };
    infra-github-squash-only = {
      expr = lib.mapAttrs (_: r: {
        inherit (r.rules) required_linear_history;
        inherit (r.rules.pull_request) allowed_merge_methods;
        inherit (r.conditions.ref_name) include;
      }) ruleset;
      expected = lib.genAttrs [ "nix-config" "nix-nvim" "nix-routeros" "nix-wallpapers" ] (_: {
        required_linear_history = true;
        allowed_merge_methods = [ "squash" ];
        include = [ "~DEFAULT_BRANCH" ];
      });
    };
  };
}
