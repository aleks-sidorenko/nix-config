{
  # treefmt needs a writable home, absent in the build sandbox
  flake-file.formatter = pkgs: pkgs.nixfmt;

  perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.nixfmt-tree;
    };
}
