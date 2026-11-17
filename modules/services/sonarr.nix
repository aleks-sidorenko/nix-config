{ den, ... }:
{
  den.aspects.services.sonarr = (import ./_arr.nix { inherit den; }).manager {
    name = "sonarr";
    title = "Sonarr";
    port = 8989;
    category = "series";
  };
}
