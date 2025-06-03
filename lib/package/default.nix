{ lib, ... }:
{
  # Returns the executable path for a given package
  # Example: getExecPath pkgs.hello -> "/nix/store/...-hello/bin/hello"
  getExecPath = package: "${package}/bin/${package.pname}";
}
