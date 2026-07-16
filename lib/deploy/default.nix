{
  lib,
  inputs,
  namespace,
}:
let
  inherit (inputs) deploy-rs;
in
rec {
  ## Create deployment configuration for use with deploy-rs.
  ##
  ## ```nix
  ## mkDeploy {
  ##   inherit self;
  ##   overrides = {
  ##     my-host.system.sudo = "doas -u";
  ##   };
  ## }
  ## ```
  ##
  #@ { self: Flake, overrides: Attrs ? {} } -> Attrs
  mkDeploy =
    {
      self,
      overrides ? { },
    }:
    let
      hosts = self.nixosConfigurations or { };
      names = builtins.attrNames hosts;
      nodes = lib.foldl (
        result: name:
        let
          host = hosts.${name};
          user = host.config.${namespace}.user.name or null;
          inherit (host.pkgs) system;
        in
        result
        // {
          ${name} = (overrides.${name} or { }) // {
            hostname = overrides.${name}.hostname or "${name}";
            profiles = (overrides.${name}.profiles or { }) // {
              system =
                (overrides.${name}.profiles.system or { })
                // {
                  path = deploy-rs.lib.${system}.activate.nixos host;
                }
                // lib.optionalAttrs (user != null) {
                  user = "root";
                  sshUser = user;
                }
                // (
                  # deploy-rs activates the system profile as root over a
                  # non-interactive SSH session. How it elevates depends on the
                  # host's privilege-escalation policy:
                  #
                  #  - doas hosts grant the deploy user passwordless access
                  #    (`noPass = true`), so we only swap in the `doas` command.
                  #  - sudo hosts that opt into passwordless sudo (e.g. the
                  #    server role sets `wheelNeedsPassword = false`) need
                  #    nothing extra.
                  #  - any other sudo host still prompts for a password, which
                  #    the non-interactive SSH session cannot supply. Enable
                  #    `interactiveSudo` so deploy-rs prompts locally and pipes
                  #    the password in over stdin (it also rewrites the sudo
                  #    command with `-S -p ""` automatically).
                  #
                  # Keying off the actual sudo policy — rather than hardcoding a
                  # host/role list — keeps this correct as hosts are added or
                  # their roles change.
                  if host.config.${namespace}.security.doas.enable or false then
                    { sudo = "doas -u"; }
                  else
                    lib.optionalAttrs (host.config.security.sudo.wheelNeedsPassword or true) {
                      interactiveSudo = true;
                    }
                );
            };
          };
        }
      ) { } names;
    in
    {
      inherit nodes;
    };
}
