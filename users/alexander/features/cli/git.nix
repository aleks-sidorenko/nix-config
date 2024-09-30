{
  pkgs,
  config,
  lib,
  ...
}: let
  ssh = "${pkgs.openssh}/bin/ssh";

  
  # git commit --amend, but for older commits
  git-fixup = pkgs.writeShellScriptBin "git-fixup" ''
    rev="$(git rev-parse "$1")"
    git commit --fixup "$@"
    GIT_SEQUENCE_EDITOR=true git rebase -i --autostash --autosquash $rev^
  '';
in {
  home.packages = [
    git-fixup
  ];
  programs.git = {
    enable = true;
    package = pkgs.gitAndTools.gitFull;
    aliases = {
      a = "commit --amend";
      br = "branch";
      c = "commit";
      ca = "!git add -A && git commit"; # Commit all changes.
      co = "checkout";
      cp = "cherry-pick";
      d = "diff";
      dc = "diff --cached";
      f = "fetch";
      git = "!exec git"; # Allow `$ git git git...`
      lc = "shortlog --email --numbered --summary";  # List contributors.
      p = "push";
      pf = "push --force-with-lease";
      r = "rebase";
      s = "status";
      w = "instaweb --httpd=webrick";  # Start web-based visualizer.
      pl = "pull --ff-only";
      m = "merge --ff-only";
      g = "log --decorate --oneline --graph";
      cc = "!f() { \
        git log --pretty=custom --decorate --date=short -S\"$1\"; \
      }; f";
      brd = "!f() { \
        git branch | grep -v \"master\" | xargs git branch -D; \
      }; f";

    };
    userName = "Alexander Sidorenko";
    userEmail = lib.mkDefault "aleks.sidorenko@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      user.signing.key = "14A3B7B14DBED4A1";
      commit.gpgSign = lib.mkDefault true;
      gpg.program = "${config.programs.gpg.package}/bin/gpg2";

      merge.conflictStyle = "zdiff3";
      commit.verbose = true;
      diff.algorithm = "histogram";
      log.date = "iso";
      column.ui = "auto";
      branch.sort = "committerdate";
      # Automatically track remote branch
      push.autoSetupRemote = true;
      # Reuse merge conflict fixes when rebasing
      rerere.enabled = true;
    };
    lfs.enable = true;
    ignores = [
      ".direnv"
      "result"
      ".jj"
    ];
  };
}
