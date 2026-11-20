{
  den.aspects.security.sudo.touch-id.darwin.security.pam.services.sudo_local = {
    touchIdAuth = true;
    # Without pam_reattach the prompt silently falls back to a password inside
    # terminal multiplexers.
    reattach = true;
  };
}
