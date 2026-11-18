{ inputs, ... }:
{
  flake-file.inputs.sops-nix = {
    url = "github:mic92/sops-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.security.sops = {
    nixos = {
      imports = [ inputs.sops-nix.nixosModules.sops ];
      sops.defaultSopsFile = ../../secrets/nixos.yaml;
    };

    darwin = {
      imports = [ inputs.sops-nix.darwinModules.sops ];
      sops = {
        defaultSopsFile = ../../secrets/darwin.yaml;
        age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      };
    };
  };
}
