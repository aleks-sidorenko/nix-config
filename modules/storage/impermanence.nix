{
  config,
  den,
  inputs,
  lib,
  ...
}:
let
  inherit (import ./_layout.nix) label root blank;

  walk = [
    "/var/lib"
    "/var/cache"
  ];

  guard =
    pkgs: pkgs.writers.writePython3Bin "persist-guard" { } (builtins.readFile ./_persist-guard.py);

  # Hosts whose install test runs the guard.
  installTested = lib.filterAttrs (
    _: host:
    host.hasAspect den.aspects.storage.impermanence && host.hasAspect den.aspects.hardware.qemu-guest
  ) den.hosts.x86_64-linux;

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

  den.aspects.storage.impermanence = {
    # Startup must finish so that every service has written its state again.
    # The state is matched, not piped: the driver's pipefail would take
    # systemctl's non-zero exit on a degraded system as a failure.
    installChecks = [
      ''machine.wait_until_succeeds("[[ $(systemctl is-system-running --wait) =~ ^(running|degraded)$ ]]")''
      ''machine.succeed("persist-guard /etc/persist-guard.json")''
    ];

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
              ignore = [ "/var/lib/junk.status" ];
            };
            passAsFile = [ "config" ];
          }
          ''
            tree=$TMPDIR/root
            mkdir -p $tree/var/lib/a $tree/var/lib/private/p $tree/var/lib/empty $tree/var/cache
            echo state > $tree/var/lib/a/db
            echo state > $tree/var/lib/private/p/db
            ln -s private/p $tree/var/lib/link
            ln -s missing $tree/var/lib/dangling
            echo state > $tree/var/lib/junk.status
            persist-guard --root $tree $configPath

            mkdir $tree/var/lib/stray
            echo state > $tree/var/lib/stray/db
            if persist-guard --root $tree $configPath > report; then
              echo "guard passed undeclared state" >&2
              exit 1
            fi
            if [ "$(cat report)" != /var/lib/stray ]; then
              echo "guard reported, expected /var/lib/stray:" >&2
              cat report >&2
              exit 1
            fi
            touch $out
          '';
    };

  evalTests = {
    persist-guard-test-only = {
      expr = lib.mapAttrs (name: host: {
        installed = hasGuard (config.installedSystem host);
        real = hasGuard config.flake.nixosConfigurations.${name};
      }) installTested;
      expected = lib.mapAttrs (_: _: {
        installed = true;
        real = false;
      }) installTested;
    };
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
