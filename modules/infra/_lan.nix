{ lib }:
{
  # A published name of a host with no lease has no address to answer with;
  # failing here beats a record pointing nowhere.
  unleasedNames =
    { leases, names }:
    let
      leased = map (l: l.name) leases;
    in
    lib.filter (n: !(lib.elem n.host leased)) names;
}
