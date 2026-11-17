{ den, ... }:
{
  den.aspects.services.radarr = (import ./_arr.nix { inherit den; }).manager {
    name = "radarr";
    title = "Radarr";
    port = 7878;
    category = "movies";
  };
}
