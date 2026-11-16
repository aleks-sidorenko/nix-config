{
  den.aspects.security.nix-access-tokens.nixos =
    { config, ... }:
    {
      sops.secrets."system-github-token" = { };

      # Anonymous GitHub API calls hit the rate limit during flake updates.
      nix.extraOptions = ''
        !include ${config.sops.secrets."system-github-token".path}
      '';
    };
}
