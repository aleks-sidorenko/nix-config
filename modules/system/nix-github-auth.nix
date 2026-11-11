{
  flake.modules.nixos.nix-github-auth =
    { config, ... }:
    {
      # Authenticated GitHub fetches avoid the anonymous API rate limit that
      # flake updates and builds otherwise hit.
      sops.secrets."system-github-token" = {
        mode = "0440";
        restartUnits = [ "nix-daemon.service" ];
      };

      nix.extraOptions = ''
        !include ${config.sops.secrets."system-github-token".path}
      '';
    };
}
