{
  # Apps pin themselves by appending to `persistent-apps` in their own darwin body.
  den.aspects.system.dock.darwin.system.defaults.dock = {
    autohide = true;
    mru-spaces = false;
    show-recents = false;
    tilesize = 48;
  };
}
