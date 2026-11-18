{
  den.aspects.system.homebrew.darwin = {
    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = false;
        upgrade = false;
        # Homebrew 6 removed `brew bundle --cleanup`, and any value other than
        # "none" makes nix-darwin pass that now-fatal switch on activation.
        cleanup = "none";
      };
    };

    environment.systemPath = [ "/opt/homebrew/bin" ];
  };
}
