# What `server` is compared with master on. Evaluated against both trees, so
# it reads only options that exist on both.
{ lib }:
{
  # Only the declarative fields: disko adds functions and `_`-prefixed internals.
  declarative =
    let
      go =
        v:
        if builtins.isFunction v then
          null
        else if builtins.isAttrs v then
          if v ? outPath then
            "<path>"
          else
            lib.filterAttrs (_: x: x != null) (
              lib.mapAttrs (_: go) (lib.filterAttrs (n: _: !lib.hasPrefix "_" n) v)
            )
        else if builtins.isList v then
          map go v
        else
          v;
    in
    go;

  # Only formatting runs the blank-snapshot hook; a deployed system never does.
  withoutHook =
    devices:
    lib.recursiveUpdate devices {
      disk.root.content.partitions.btrfs.content.postCreateHook = null;
    };

  mounts = lib.mapAttrs (
    _: v: {
      inherit (v)
        neededForBoot
        device
        fsType
        options
        ;
    }
  );
}
