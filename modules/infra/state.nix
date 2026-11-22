{ config, lib, ... }:
{
  # The wrapper writes the state-encryption HCL, which reads this variable.
  den.aspects.infra.state.terranix =
    { stack, ... }:
    {
      variable.state_passphrase = {
        type = "string";
        sensitive = true;
      };
      _meta.secrets.TF_VAR_state_passphrase = {
        file = "${stack.dir}/secrets.yaml";
        key = "state-passphrase";
      };
    };

  evalTests.infra-state-passphrase-per-stack = {
    expr = lib.mapAttrs (_: stack: stack.meta.secrets.TF_VAR_state_passphrase) config.infraStacks;
    expected = lib.mapAttrs (name: _: {
      file = "infra/${name}/secrets.yaml";
      key = "state-passphrase";
    }) config.den.stacks;
  };
}
