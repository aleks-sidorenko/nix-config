# Installs each VM host's real config into disko's test VM the way bootstrap
# does (partition, format, install, boot), then checks what survives a power cycle.
{
  config,
  den,
  lib,
  ...
}:
let
  inherit (import ../_lib/install-test.nix) settled;

  systemOf = name: config.flake.nixosConfigurations.${name};

  testSecretNames = name: lib.attrNames (systemOf name).config.sops.secrets;

  # The host's own key can't exist in the VM, so the test brings a throwaway
  # key and a secrets file encrypted to it, both generated at build time.
  testSecrets =
    pkgs: names:
    pkgs.runCommand "test-secrets"
      {
        nativeBuildInputs = [
          pkgs.age
          pkgs.sops
          pkgs.mkpasswd
        ];
      }
      ''
        mkdir $out
        age-keygen -o $out/key.txt 2>/dev/null
        for name in ${lib.escapeShellArgs names}; do
          case "$name" in
            user-*-password) value=$(mkpasswd -m sha-512 test) ;;
            *) value=test ;;
          esac
          printf "%s: '%s'\n" "$name" "$value" >> plain.yaml
        done
        sops --encrypt --age "$(age-keygen -y $out/key.txt)" \
          --input-type yaml --output-type yaml plain.yaml > $out/secrets.yaml
      '';

  # Every node of a disko layout with its option path, so the test can
  # override nodes without knowing the layout's names.
  diskoNodes =
    let
      children =
        path: key: node:
        lib.concatLists (
          lib.mapAttrsToList (
            name:
            walk (
              path
              ++ [
                key
                name
              ]
            )
          ) (node.${key} or { })
        );
      walk =
        path: node:
        [ { inherit path node; } ]
        ++ lib.optionals (node.content or null != null) (walk (path ++ [ "content" ]) node.content)
        ++ children path "partitions" node
        ++ children path "subvolumes" node;
    in
    children [ "disko" "devices" ] "disk";

  # The passphrase disko's test harness writes for the installer.
  luksKey = "/tmp/secret.key";

  testModule =
    host:
    { config, pkgs, ... }:
    let
      original = (systemOf host.name).config;
      secrets = testSecrets pkgs (testSecretNames host.name);
      secretSteps = lib.filter (step: original.system.activationScripts ? ${step}) [
        "setupSecrets"
        "setupSecretsForUsers"
      ];

      nodes = diskoNodes original.disko.devices;
      luks = lib.filter (n: n.node.type or null == "luks") nodes;
      swapfiles = lib.concatMap (
        n:
        lib.mapAttrsToList (
          name: _:
          n.path
          ++ [
            "swap"
            name
            "size"
          ]
        ) (n.node.swap or { })
      ) nodes;

      root = host.settings.storage.impermanence.root;
      persisted = config.environment.persistence.${root};
      persistedPaths = map (d: d.dirPath) persisted.directories ++ map (f: f.filePath) persisted.files;
      passwordFiles = lib.mapAttrsToList (
        _: user: config.users.users.${user.userName}.hashedPasswordFile
      ) host.users;

      call = method: command: "machine.${method}(${builtins.toJSON command})";
      succeed = call "succeed";
      exists = path: succeed "test -e ${lib.escapeShellArg path}";
      bootCheck = ''machine.wait_for_unit("multi-user.target")'';

      # home-manager's activation asks nix-daemon to chown the store, which
      # the test VM's store refuses (EINVAL); it fails in every install VM,
      # whatever the config.
      vmFailures = map (user: "home-manager-${user.userName}.service") (lib.attrValues host.users);
      noFailedUnits = ''
        failed = set(machine.succeed("systemctl list-units --state=failed --plain --no-legend --full | cut -d ' ' -f 1").split())
        unexpected = failed - set(${builtins.toJSON vmFailures})
        assert not unexpected, f"failed units: {sorted(unexpected)}"
      '';
    in
    {
      config = lib.mkMerge (
        # disko's test disks are 4 GB; a real-sized swapfile fills btrfs and
        # leaves it read-only.
        map (path: lib.setAttrByPath path (lib.mkForce "256M")) swapfiles
        # Read at format time in the installer and at boot from the initrd.
        ++ map (
          n:
          lib.setAttrByPath (
            n.path
            ++ [
              "settings"
              "keyFile"
            ]
          ) luksKey
        ) luks
        ++ [
          {
            installTest.extraConfig = {
              # The harness puts the key into the installer only.
              boot.initrd.secrets = lib.mkIf (luks != [ ]) {
                ${luksKey} = pkgs.writeText "secret.key" "secretsecret";
              };

              # sops-nix refuses a key file in the store, so copy it out
              # before either secrets step runs.
              system.activationScripts = {
                testAgeKey = {
                  deps = [ "specialfs" ];
                  text = "install -D -m 600 ${secrets}/key.txt /run/test-age.key";
                };
              }
              // lib.genAttrs secretSteps (_: {
                deps = [ "testAgeKey" ];
              });

              sops = {
                defaultSopsFile = lib.mkForce "${secrets}/secrets.yaml";
                # A build output is only known at build time; validating it
                # would need import-from-derivation.
                validateSopsFiles = false;
                age.keyFile = "/run/test-age.key";
                age.sshKeyPaths = lib.mkForce [ ];
              };
            };

            disko.tests = {
              extraConfig.imports = [ config.installTest.extraConfig ];

              extraChecks = lib.mkMerge [
                # After nginx's checks (mkAfter) and before the guard (1600),
                # so a unit any check broke counts.
                (lib.mkOrder 1550 (
                  lib.concatLines [
                    settled
                    noFailedUnits
                  ]
                ))
                # Ahead of the host's own `installChecks`.
                (lib.mkBefore (
                  lib.concatLines (
                    [
                      bootCheck
                      (succeed "systemctl is-active sshd.service")
                    ]
                    ++ map (user: succeed "id ${user.userName}") (lib.attrValues host.users)
                    ++ map exists passwordFiles
                    ++ [
                      (succeed "touch /root-marker ${lib.escapeShellArg "${root}/persist-marker"}")
                      # The test's QEMU exits on reboot, so power-cycle the same disks.
                      "machine.shutdown()"
                      "machine.start()"
                      bootCheck
                      (call "fail" "test -e /root-marker")
                      (exists "${root}/persist-marker")
                    ]
                    # Files not yet in the persistence root are linked on the
                    # first boot and only bind-mounted from the second.
                    ++ map (path: succeed "findmnt --mountpoint ${lib.escapeShellArg path}") persistedPaths
                    ++ map exists passwordFiles
                  )
                ))
              ];
            };
          }
        ]
      );
    };

  testSystem = host: (systemOf host.name).extendModules { modules = [ (testModule host) ]; };

  # What the test boots: disko applies `extraConfig` only to the installed
  # system. `modules` lets eval tests add definitions before that split.
  installedWith =
    host: modules:
    let
      system = (testSystem host).extendModules { inherit modules; };
    in
    system.extendModules { modules = [ system.config.disko.tests.extraConfig ]; };

  installedSystem = host: installedWith host [ ];

  installTest = host: (testSystem host).config.system.build.installTest;

  vmHostsOf =
    system:
    lib.filterAttrs (_: host: host.hasAspect den.aspects.hardware.qemu-guest) (
      den.hosts.${system} or { }
    );
  vmHosts = vmHostsOf "x86_64-linux";
in
{
  options.installedSystem = lib.mkOption {
    type = lib.types.functionTo lib.types.raw;
    readOnly = true;
    description = "A VM host's system as its install test boots it, for aspects' eval tests.";
  };

  config = {
    inherit installedSystem;

    perSystem =
      { system, ... }:
      {
        checks = lib.mapAttrs' (name: host: lib.nameValuePair "install-${name}" (installTest host)) (
          vmHostsOf system
        );
      };

    evalTests = {
      install-test-exists = {
        expr = config.allSystems.x86_64-linux.checks ? install-base-vm;
        expected = true;
      };
      install-test-no-real = {
        expr = config.allSystems.x86_64-linux.checks ? install-server;
        expected = false;
      };
      install-checks-failed-units = {
        expr = {
          tested = vmHosts != { };
          checked = lib.mapAttrs (
            _: host:
            lib.hasInfix "systemctl list-units --state=failed" (installedSystem host)
            .config.disko.tests.extraChecks
          ) vmHosts;
        };
        expected = {
          tested = true;
          checked = lib.mapAttrs (_: _: true) vmHosts;
        };
      };
      install-base-vm-evaluates = {
        expr = lib.isString config.allSystems.x86_64-linux.checks.install-base-vm.drvPath;
        expected = true;
      };
      # The probe shares a top-level key with impermanence's accommodation,
      # which disko's untyped option would have dropped.
      installed-accommodations-merge = {
        expr =
          let
            c =
              (installedWith den.hosts.x86_64-linux.server-vm [
                { installTest.extraConfig.environment.etc.merge-probe.text = ""; }
              ]).config;
          in
          {
            autoconnect = c.systemd.services.tailscaled-autoconnect.enable;
            guard = c.environment.etc ? "persist-guard.json";
            probe = c.environment.etc ? merge-probe;
            inherit (c.nix) extraOptions;
            inherit (c.sops.age) keyFile;
          };
        expected = {
          autoconnect = false;
          guard = true;
          probe = true;
          extraOptions = "";
          keyFile = "/run/test-age.key";
        };
      };
      test-secrets-cover-host = {
        expr = testSecretNames "base-vm";
        expected = lib.attrNames (installedSystem den.hosts.x86_64-linux.base-vm).config.sops.secrets;
      };
    };
  };
}
