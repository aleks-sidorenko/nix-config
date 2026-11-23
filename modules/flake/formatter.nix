{
  # treefmt needs a writable home, absent in the build sandbox
  flake-file.formatter = pkgs: pkgs.nixfmt;

  perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.nixfmt-tree.override {
        runtimeInputs = [ pkgs.just ];
        # `--fmt` is still unstable in just; it takes one justfile per run.
        settings.formatter.just = {
          command = "just";
          options = [
            "--unstable"
            "--fmt"
            "--justfile"
          ];
          includes = [ "justfile" ];
        };
      };
    };
}
