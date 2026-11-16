# Shared by the install-test harness and the aspects that add checks to it.
{
  # Every unit has started or failed, and every service has written its state.
  # The state is matched, not piped: the driver's pipefail would take
  # systemctl's non-zero exit on a degraded system as a failure.
  settled = ''machine.wait_until_succeeds("[[ $(systemctl is-system-running --wait) =~ ^(running|degraded)$ ]]")'';
}
