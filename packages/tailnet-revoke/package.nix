{
  writeShellApplication,
  coreutils,
  curl,
  jq,
  sops,
}:
writeShellApplication {
  name = "tailnet-revoke";
  runtimeInputs = [
    coreutils
    curl
    jq
    sops
  ];
  text = builtins.readFile ./tailnet-revoke.sh;
  meta.description = "Delete a host's stale devices from the tailnet";
}
