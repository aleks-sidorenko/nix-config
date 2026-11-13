{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.just
          pkgs.statix
          pkgs.deadnix
          pkgs.sops
          pkgs.age
          pkgs.nixfmt-tree
          pkgs.nvd
        ];
      };
    };
}
