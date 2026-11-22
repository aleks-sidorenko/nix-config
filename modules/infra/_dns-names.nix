{ lib }:
{
  # Two hosts claiming the same name don't error at the DNS layer, they
  # round-robin: each request lands on a different host with different state,
  # silently. The stand-in arrangement makes that one role toggle away, so it
  # has to fail here rather than wait for both hosts to be reachable at once.
  duplicateClaims =
    records:
    lib.filterAttrs (_: hosts: lib.length (lib.unique hosts) > 1) (
      lib.mapAttrs (_: map (r: r.hostname)) (lib.groupBy (r: r.name) records)
    );

  # Same shape of bug, one host over: a name declared twice on ONE host slips
  # past duplicateClaims (only one hostname per group, so `unique` collapses
  # it) and reaches the plan as two identical service_records entries, which
  # fails there with a "duplicate key" error but no clue which host caused it.
  # Catch it here, at the source.
  intraHostDuplicates =
    hosts:
    let
      duplicateName = name: names: lib.length (lib.filter (n: n == name) names) > 1;
    in
    lib.filter (h: h.duplicates != [ ]) (
      map (h: {
        inherit (h) hostname;
        duplicates = lib.unique (lib.filter (n: duplicateName n h.names) h.names);
      }) hosts
    );
}
