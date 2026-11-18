{ pkgs }:
pkgs.writeShellApplication {
  name = "disk-report";
  # GNU coreutils on macOS too, for numfmt and `stat -c`.
  runtimeInputs = builtins.attrValues {
    inherit (pkgs)
      coreutils
      findutils
      gawk
      gnugrep
      dust
      ;
  };
  text = builtins.readFile ./_disk-report.sh;
  meta.description = "Rank what is using disk space and print the command that reclaims each item";
}
