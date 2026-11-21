{
  den.aspects.system.input.darwin.system.defaults = {
    trackpad = {
      Clicking = true;
      TrackpadThreeFingerDrag = true;
    };
    NSGlobalDomain = {
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      # External keyboards that report an Apple vendor ID get the top-row
      # media mapping too, but their firmware fn never reaches macOS.
      "com.apple.keyboard.fnState" = true;
    };

    # Frees Ctrl+Arrow so nvim's window-resize bindings reach the editor.
    CustomUserPreferences."com.apple.symbolichotkeys".AppleSymbolicHotKeys = {
      "32".enabled = false;
      "36".enabled = false;
      "79".enabled = false;
      "81".enabled = false;
    };
  };
}
