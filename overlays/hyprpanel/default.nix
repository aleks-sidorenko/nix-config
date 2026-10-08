{ inputs, ... }:
_final: prev: {
  hyprpanel = inputs.hyprpanel.packages.${prev.stdenv.hostPlatform.system}.default;
}
