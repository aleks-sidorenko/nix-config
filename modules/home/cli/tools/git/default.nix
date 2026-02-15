{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.tools.git;

  rewriteURL = lib.mapAttrs' (key: value: {
    name = "url.${key}";
    value = {
      insteadOf = value;
    };
  }) cfg.urlRewrites;
in
{
  options.${namespace}.cli.tools.git = with types; {
    enable = mkEnableOption "Whether or not to enable git";
    email = mkOpt (nullOr str) "aleks.sidorenko@gmail.com" "The email to use with git";
    fullName = mkOpt (nullOr str) "Alexander Sidorenko" "The full name to use with git";
    urlRewrites = mkOpt (attrsOf str) { } "url we need to rewrite i.e. ssh to http";
    allowedSigners = mkOpt str "~/.ssh/id_ed25519.pub" "The public key used for signing commits";
  };

  config = mkIf cfg.enable {
    home.file.".ssh/allowed_signers".text = "* ${cfg.allowedSigners}";

    programs.git = {
      enable = true;

      settings = {

        user = {
          name = cfg.fullName;
          email = cfg.email;
        };

        gpg.format = "ssh";
        gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
        commit.gpgsign = true;
        user.signingkey = cfg.allowedSigners;

        diff.tool = "difftastic";
        difftool = {
          prompt = "false";
          difftastic.cmd = "difft \"$LOCAL\" \"$REMOTE\"";
        };

        merge.tool = "nvimdiff";
        mergetool = {
          prompt = false;
          keepBackup = false;
        };

        log = {
          showSignature = "true";
        };

        pull = {
          rebase = true;
        };

        init = {
          defaultBranch = "master";
        };

        push = {
          default = "current";
          autoSetupRemote = true;
        };

        alias = {
          # Status
          s = "status -sb";
          st = "status";

          # Commits
          c = "commit";
          cm = "commit -m";
          ca = "commit --amend";
          can = "commit --amend --no-edit";
          cma = "commit -am";

          # Branches
          br = "branch";
          bra = "branch -a";
          brd = "branch -d";
          brD = "branch -D";
          brdd = "!git branch | grep -v '^*' | xargs git branch -d"; # delete all local branches that are not the current branch
          brdf = "!git branch | grep -v '^*' | xargs git branch -D"; # delete all local branches that are not the current branch and force delete them

          # Checkout/Switch
          co = "checkout";
          cob = "checkout -b";
          sw = "switch";
          swc = "switch -c";

          # Diff
          d = "diff";
          ds = "diff --staged";
          dc = "diff --cached";
          dw = "diff --word-diff";

          # Log
          lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
          lga = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --all";
          ll = "log --oneline";
          last = "log -1 HEAD --stat";

          # Push/Pull
          p = "push";
          pf = "push --force-with-lease";
          pl = "pull";
          plr = "pull --rebase";

          # Fetch
          f = "fetch";
          fa = "fetch --all --prune";

          # Rebase
          rb = "rebase";
          rbi = "rebase -i";
          rbc = "rebase --continue";
          rba = "rebase --abort";
          rbs = "rebase --skip";

          # Reset
          unstage = "reset HEAD --";
          undo = "reset --soft HEAD~1";
          hard = "reset --hard";
          hardh = "reset --hard HEAD";

          # Stash
          ss = "stash save";
          sp = "stash pop";
          sl = "stash list";
          sd = "stash drop";
          sa = "stash apply";

          # Merge
          m = "merge";
          ma = "merge --abort";
          mc = "merge --continue";

          # Cherry-pick
          cp = "cherry-pick";
          cpa = "cherry-pick --abort";
          cpc = "cherry-pick --continue";

          # Clean
          clean-all = "clean -fd";
          pristine = "!git reset --hard && git clean -fdx";

          # Remote
          rv = "remote -v";
          ra = "remote add";
          rr = "remote remove";

          # Worktree
          wt = "worktree";
          wtl = "worktree list";
          wta = "worktree add";
          wtr = "worktree remove";

          # Misc
          aliases = "config --get-regexp alias";
          whoami = "config user.email";
          root = "rev-parse --show-toplevel";
          contributors = "shortlog -sn";
          today = "log --since=midnight --oneline --author='$(git config user.email)'";
          week = "log --since='1 week ago' --oneline --author='$(git config user.email)'";
        };

      };

      signing = {
        signByDefault = true;
        key = cfg.allowedSigners;
      };

      ignores = [
        ".direnv"
        "result"
      ];

    };

    programs.difftastic = {
      enable = true;
    };

  };
}
