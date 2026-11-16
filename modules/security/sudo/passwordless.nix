{
  # Deploys run sudo over a non-interactive SSH session that can't answer a prompt.
  den.aspects.security.sudo.passwordless.nixos.security.sudo.wheelNeedsPassword = false;
}
