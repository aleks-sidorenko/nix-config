# Installs server's real disk layout into a throwaway VM the way bootstrap does
# (partition, format, install, boot), then proves the root rollback: what is
# written to / is gone after a reboot, what is written to /persist survives.
{ config, lib, ... }:
let
  server = config.flake.nixosConfigurations.server;

  # The host's own key can't exist in the VM, so the test brings a throwaway
  # key and a secrets file encrypted to it, both generated at build time.
  testSecrets =
    pkgs:
    pkgs.runCommand "server-test-secrets"
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
        recipient=$(age-keygen -y $out/key.txt)
        cat > plain.yaml <<YAML
        user-alexander-password: '$(mkpasswd -m sha-512 test)'
        system-tailscale-auth-key: tskey-test
        service-ingress-htpasswd: 'test:{PLAIN}test'
        system-github-token: access-tokens = github.com=test
        YAML
        sops --encrypt --age "$recipient" --input-type yaml --output-type yaml plain.yaml > $out/secrets.yaml
      '';

  testModule =
    { pkgs, ... }:
    let
      secrets = testSecrets pkgs;
    in
    {
      # disko's test disks are 4 GB; the real 8G swapfile fills btrfs and
      # leaves it read-only. Everything else is the real layout.
      disko.devices.disk.root.content.partitions.btrfs.content.subvolumes."@swap".swap.swapfile.size =
        lib.mkForce "256M";

      disko.tests = {
        extraConfig = {
          # sops-nix refuses a key file in the store, so copy it out before
          # either secrets step runs.
          system.activationScripts = {
            testAgeKey.text = "install -D -m 600 ${secrets}/key.txt /run/test-age.key";
            setupSecrets.deps = [ "testAgeKey" ];
            setupSecretsForUsers.deps = [ "testAgeKey" ];
          };

          # Joining needs the network the VM doesn't have; each try holds up
          # multi-user.target for minutes. tailscaled itself still runs.
          systemd.services.tailscaled-autoconnect.enable = false;

          sops = {
            defaultSopsFile = lib.mkForce "${secrets}/secrets.yaml";
            # A build output is only known at build time; validating it would
            # need import-from-derivation.
            validateSopsFiles = false;
            age.keyFile = "/run/test-age.key";
            age.sshKeyPaths = lib.mkForce [ ];
          };
        };

        extraChecks = ''
          machine.wait_for_unit("multi-user.target")
          machine.succeed("systemctl is-active sshd.service tailscaled.service")
          machine.succeed("test -e /run/secrets-for-users/user-alexander-password")

          machine.succeed("touch /root-marker /persist/persist-marker")
          # The test's QEMU exits on reboot, so power-cycle the same disks.
          machine.shutdown()
          machine.start()
          machine.wait_for_unit("multi-user.target")

          machine.succeed("journalctl -b -u impermanence-rollback-root --no-pager | grep -q 'Restoring blank subvolume'")
          machine.succeed("test -e /root-marker")
          machine.succeed("test -e /persist/persist-marker")
        '';
      };
    };
in
{
  perSystem =
    { system, ... }:
    lib.optionalAttrs (system == "x86_64-linux") {
      checks.server-install =
        (server.extendModules { modules = [ testModule ]; }).config.system.build.installTest;
    };
}
