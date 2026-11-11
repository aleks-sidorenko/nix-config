{
  config,
  inputs,
  lib,
  ...
}:
let
  c =
    (config.builders.nixos "x86_64-linux" {
      imports = with config.flake.modules.nixos; [
        sops
        nix-github-auth
      ];
      system.stateVersion = "26.05";
    }).config;
in
{
  flake.modules.nixos.sops = {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    # Read from /persist directly: sops-nix decrypts during activation, before
    # impermanence has bind-mounted the key back into /etc.
    sops.age.sshKeyPaths = [ "${config.constants.persistence.root}/etc/ssh/ssh_host_ed25519_key" ];
  };

  evalTests = {
    sops-key-under-persist = {
      expr = c.sops.age.sshKeyPaths;
      expected = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
    };
    # The host names its own secrets file, so a new host can't silently read
    # another's.
    sops-no-default-file = {
      expr = (builtins.tryEval c.sops.defaultSopsFile).success;
      expected = false;
    };
    nix-github-auth-include = {
      expr = lib.hasInfix "!include /run/secrets/system-github-token" c.nix.extraOptions;
      expected = true;
    };
    nix-github-auth-restarts-daemon = {
      expr = c.sops.secrets."system-github-token".restartUnits;
      expected = [ "nix-daemon.service" ];
    };
  };
}
