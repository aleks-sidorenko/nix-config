{ lib, ... }:
{
  den.aspects.dev.git = {
    homeManager =
      { user, ... }:
      let
        identity = ../../identities/${user.identity};
        inherit (builtins.fromJSON (builtins.readFile (identity + "/git.json"))) name email;
        signingKey = lib.trim (builtins.readFile (identity + "/ssh.pub"));
      in
      {
        # Git verifies signatures against this file; without it `log --show-signature` cannot.
        home.file.".ssh/allowed_signers".text = "${email} ${signingKey}";

        programs = {
          git = {
            enable = true;
            lfs.enable = true;
            ignores = [
              ".direnv"
              "result"
            ];

            signing = {
              signByDefault = true;
              # The key itself, not a file: the private half lives in the agent.
              key = "key::${signingKey}";
            };

            settings = {
              user = { inherit name email; };

              gpg.format = "ssh";
              gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";

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

              log.showSignature = "true";
              pull.rebase = true;
              init.defaultBranch = "master";
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
          };

          difftastic.enable = true;
        };
      };
  };
}
