{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  # The concrete key material is resolved by `lib.${namespace}.resolveIdentity
  # config`; this module only provides the override point for which identity a
  # home uses. See identities/README.md.
  options.${namespace}.security.identity = with types; {
    name = mkOpt str config.${namespace}.user.name ''
      Identity (folder under the top-level identities/) whose public key material
      to use. Defaults to the account username; override when one person uses
      several accounts (e.g. oleksandrsy@workbook reusing "alexander").
    '';
  };
}
