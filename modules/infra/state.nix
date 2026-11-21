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
        file = "infra/${stack.name}/secrets.yaml";
        key = "state-passphrase";
      };
    };
}
