{ den, inputs, ... }:
{
  flake-file.inputs.sops-nix = {
    url = "github:mic92/sops-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.security.sops = {
    includes = [
      (den.lib.policy.when (
        { hasAspect, ... }: hasAspect den.aspects.storage.impermanence
      ) den.aspects.security.sops.impermanent)
    ];

    nixos = {
      imports = [ inputs.sops-nix.nixosModules.sops ];
      sops.defaultSopsFile = ../../../secrets/nixos.yaml;
    };

    darwin = {
      imports = [ inputs.sops-nix.darwinModules.sops ];
      sops = {
        defaultSopsFile = ../../../secrets/darwin.yaml;
        age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      };
    };
  };
}
