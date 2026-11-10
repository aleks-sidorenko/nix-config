{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        NIX_CONFIG = "extra-experimental-features = nix-command flakes";

        shellHook = ''
          export FLAKE_DIR="$HOME/.nix-config"
        '';

        packages = with pkgs; [
          nix
          nh
          deploy-rs
          statix
          deadnix
          alejandra
          home-manager
          git
          sops
          ssh-to-age
          gnupg
          age
          mkpasswd
          just
          shellcheck
        ];
      };
    };
}
