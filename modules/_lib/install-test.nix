# Shared by the install-test harness and the aspects that add to it.
{ den, lib }:
let
  isInstallTested = host: host.hasAspect den.aspects.hardware.qemu-guest;

  # Hosts whose install test boots `aspect`.
  testing =
    aspect:
    lib.filterAttrs (_: host: isInstallTested host && host.hasAspect aspect) den.hosts.x86_64-linux;
in
{
  inherit isInstallTested;

  # An eval test that `probe name host` is `expected` on every host whose
  # install test boots `aspect`; with no such host it fails instead of
  # passing vacuously.
  perTestedHost =
    aspect: probe: expected:
    let
      hosts = testing aspect;
    in
    {
      expr = {
        tested = hosts != { };
        hosts = lib.mapAttrs probe hosts;
      };
      expected = {
        tested = true;
        hosts = lib.mapAttrs (_: _: expected) hosts;
      };
    };

  # Every unit has started or failed, and every service has written its state.
  # The state is matched, not piped: the driver's pipefail would take
  # systemctl's non-zero exit on a degraded system as a failure.
  settled = ''machine.wait_until_succeeds("[[ $(systemctl is-system-running --wait) =~ ^(running|degraded)$ ]]")'';
}
