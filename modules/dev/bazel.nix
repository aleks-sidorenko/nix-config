{
  # Global because the launcher pins no version: it runs whatever a repo's
  # .bazelversion names, and IDEs started outside a shell need `bazel` on PATH.
  den.aspects.dev.bazel.homeManager =
    { pkgs, ... }:
    {
      home.packages = [
        (pkgs.runCommand "bazel" { } ''
          mkdir -p $out/bin
          ln -s ${pkgs.bazelisk}/bin/bazelisk $out/bin/bazel
        '')
        pkgs.bazelisk
        pkgs.bazel-buildtools
      ];
    };
}
