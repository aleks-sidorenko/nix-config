{
  config,
  den,
  inputs,
  lib,
  ...
}:
let
  inherit (import ./_layout.nix) label root blank;
  inherit (config.installTests) perTestedHost settled;

  walk = [
    "/var/lib"
    "/var/cache"
  ];

  guard =
    pkgs: pkgs.writers.writePython3Bin "persist-guard" { } (builtins.readFile ./_persist-guard.py);

  guardCheck = ''machine.succeed("persist-guard /etc/persist-guard.json")'';

  lastCheck =
    system:
    lib.last (lib.filter (l: l != "") (lib.splitString "\n" system.config.disko.tests.extraChecks));

  hasGuard = system: system.config.environment.etc ? "persist-guard.json";

  merge = entries: {
    directories = lib.unique (lib.concatMap (e: e.directories or [ ]) entries);
    files = lib.unique (lib.concatMap (e: e.files or [ ]) entries);
    ignore = lib.unique (lib.concatMap (e: e.ignore or [ ]) entries);
  };

  # Merged with the aspects' entries, so one repeating a base path can't trip
  # impermanence's duplicate-path assertion.
  collect =
    persist:
    merge (
      [
        {
          # systemd runs on every host; it keeps the stamps of `Persistent=`
          # timers and the random seed here.
          directories = [
            "/var/lib/nixos"
            "/var/lib/systemd"
          ];
          files = [ "/etc/machine-id" ];
          # Login and rotation bookkeeping and the man page index, all rebuilt
          # as the system runs.
          ignore = [
            "/var/lib/lastlog"
            "/var/lib/logrotate.status"
            "/var/cache/man"
          ];
        }
      ]
      ++ persist
    );

  rollback = ''
    mkdir /tmp -p
    MNTPOINT=$(mktemp -d)
    (
      # The device may still be settling right after it appears.
      for attempt in 1 2 3; do
        if mount -t btrfs -o subvol=/ /dev/disk/by-label/${label} "$MNTPOINT"; then
          break
        fi
        if [ $attempt -lt 3 ]; then
          echo "Mount attempt $attempt failed, retrying in 1 second..."
          sleep 1
        else
          echo "Mount failed after 3 attempts"
          exit 1
        fi
      done
      trap 'umount $MNTPOINT 2>/dev/null || true; rm -rf $MNTPOINT' EXIT

      # btrfs refuses to delete a subvolume that still holds others.
      btrfs subvolume list -o "$MNTPOINT/${root}" | cut -f9 -d ' ' |
      while read -r subvolume; do
        btrfs subvolume delete "$MNTPOINT/$subvolume"
      done && btrfs subvolume delete "$MNTPOINT/${root}"

      btrfs subvolume snapshot "$MNTPOINT/${blank}" "$MNTPOINT/${root}"
    )
  '';
in
{
  flake-file.inputs.impermanence.url = "github:nix-community/impermanence";

  den.quirks.persist.description = "System state kept across reboots: { directories ? [ ]; files ? [ ]; ignore ? [ ]; }. `ignore` names throwaway state, which the install test's undeclared-state guard then accepts.";

  den.aspects.storage.impermanence = {
    settings.root = lib.mkOption {
      type = lib.types.str;
      default = "/persist";
      description = "Where impermanent hosts keep state that survives a reboot.";
    };

    nixos =
      {
        config,
        host,
        options,
        persist,
        pkgs,
        ...
      }:
      let
        persistRoot = host.settings.storage.impermanence.root;
        state = collect persist;
        persisted = config.environment.persistence.${persistRoot};
      in
      {
        imports = [ inputs.impermanence.nixosModules.impermanence ];

        config = {
          boot.initrd = {
            supportedFilesystems = [ "btrfs" ];
            systemd.services.impermanence-rollback-root =
              let
                device = "dev-disk-by\\x2dlabel-${label}.device";
              in
              {
                description = "Roll the btrfs root back to its blank snapshot";
                wantedBy = [ "initrd.target" ];
                requires = [ device ];
                after = [
                  device
                  "systemd-cryptsetup@${label}.service"
                ];
                before = [ "sysroot.mount" ];
                unitConfig.DefaultDependencies = "no";
                serviceConfig.Type = "oneshot";
                script = rollback;
              };
          };

          # Every boot would otherwise be the first sudo, with its lecture.
          security.sudo.extraConfig = ''
            Defaults lecture = never
          '';

          environment.persistence.${persistRoot} = {
            hideMounts = true;
            inherit (state) directories files;
          };

          # Last, after the harness's settle check (mkAfter): any check may
          # make a service write state, and the guard must see all of it.
          disko.tests.extraChecks = lib.mkOrder 1600 (
            lib.concatLines [
              settled
              guardCheck
            ]
          );

          # Fails the install test on state that a reboot would lose unnoticed.
          installTest.extraConfig.environment = {
            systemPackages = [ (guard pkgs) ];
            etc."persist-guard.json".text = builtins.toJSON {
              inherit walk;
              inherit (state) ignore;
              persisted = map (d: d.dirPath) persisted.directories ++ map (f: f.filePath) persisted.files;
            };
          };
        }
        # Secrets decrypt before the bind mounts exist, so read the key where it really lives.
        // lib.optionalAttrs (options ? sops) {
          sops.age.sshKeyPaths = map (key: persistRoot + key.path) (
            lib.filter (key: key.type == "ed25519") config.services.openssh.hostKeys
          );
        };
      };
  };

  perSystem =
    { pkgs, ... }:
    {
      checks.persist-guard =
        pkgs.runCommand "persist-guard"
          {
            nativeBuildInputs = [ (guard pkgs) ];
            config = builtins.toJSON {
              inherit walk;
              persisted = [
                "/var/lib/a"
                "/var/lib/private/p"
              ];
              # Declared paths are normalised.
              ignore = [
                "/var/lib/junk.status"
                "/var/lib/scratch/"
              ];
            };
            passAsFile = [ "config" ];
          }
          ''
            tree=$TMPDIR/root
            # Fails unless the guard reports exactly $1, or passes when $1 is empty.
            expect() {
              if persist-guard --root $tree $configPath > report; then
                [ -z "$1" ] && return
                echo "guard passed, expected $1" >&2
              else
                [ "$(cat report)" = "$1" ] && return
                echo "guard reported, expected ''${1:-nothing}:" >&2
                cat report >&2
              fi
              exit 1
            }

            mkdir -p $tree/var/lib/a $tree/var/lib/private/p $tree/var/lib/empty $tree/var/lib/scratch $tree/var/cache
            echo state > $tree/var/lib/a/db
            echo state > $tree/var/lib/private/p/db
            echo state > $tree/var/lib/scratch/tmp
            ln -s private/p $tree/var/lib/link
            ln -s missing $tree/var/lib/dangling
            touch $tree/var/lib/flag
            ln -s flag/missing $tree/var/lib/through-file
            ln -s loop-b/x $tree/var/lib/loop-a
            ln -s loop-a/x $tree/var/lib/loop-b
            echo state > $tree/var/lib/junk.status
            expect ""

            # Named on its own, not as the parent that holds a declared child.
            mkdir $tree/var/lib/private/q
            echo state > $tree/var/lib/private/q/db
            expect /var/lib/private/q
            rm -r $tree/var/lib/private/q

            mkdir -p $tree/opt/data
            echo state > $tree/opt/data/db
            ln -s /opt/data $tree/var/lib/elsewhere
            expect /var/lib/elsewhere
            rm $tree/var/lib/elsewhere

            mkdir $tree/var/lib/stray
            echo state > $tree/var/lib/stray/db
            expect /var/lib/stray
            touch $out
          '';
    };

  evalTests = {
    persist-guard-test-only =
      perTestedHost den.aspects.storage.impermanence
        (name: host: {
          installed = hasGuard (config.installTests.installedSystem host);
          real = hasGuard config.flake.nixosConfigurations.${name};
        })
        {
          installed = true;
          real = false;
        };
    persist-guard-runs-last = perTestedHost den.aspects.storage.impermanence (
      _: host: lastCheck (config.installTests.installedSystem host)
    ) guardCheck;
    persist-dedupes-base = {
      expr = collect [ { directories = [ "/var/lib/nixos" ]; } ];
      expected = {
        directories = [
          "/var/lib/nixos"
          "/var/lib/systemd"
        ];
        files = [ "/etc/machine-id" ];
        ignore = [
          "/var/lib/lastlog"
          "/var/lib/logrotate.status"
          "/var/cache/man"
        ];
      };
    };
    persist-collects-ignore = {
      expr = collect [ { ignore = [ "/var/lib/x" ]; } ];
      expected = {
        directories = [
          "/var/lib/nixos"
          "/var/lib/systemd"
        ];
        files = [ "/etc/machine-id" ];
        ignore = [
          "/var/lib/lastlog"
          "/var/lib/logrotate.status"
          "/var/cache/man"
          "/var/lib/x"
        ];
      };
    };
  };
}
