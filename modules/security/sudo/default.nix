{
  # Non-wheel users can't even run sudo, so a sudo exploit needs wheel first.
  den.aspects.security.sudo.nixos.security.sudo.execWheelOnly = true;
}
