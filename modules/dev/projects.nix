{ den, ... }:
{
  den.aspects.dev.projects = {
    # Reads the git identity's accounts, so "who am I on GitHub" stays in one place.
    includes = [ den.aspects.dev.git ];

    homeManager =
      { config, host, ... }:
      let
        projectsHome = "${config.home.homeDirectory}/Projects";
        selfOwnersFish = builtins.concatStringsSep " " host.settings.dev.git.accounts;
      in
      {
        # Full path (not ~) so it resolves the same in scripts and non-interactive shells.
        home.sessionVariables = {
          PROJECTS_HOME = projectsHome;
          PROJECTS_ARCHIVE = "${projectsHome}/_archive";
        };

        programs.fish.functions = {
          prj = {
            description = "Jump to a project (<org>/<repo>); -a searches $PROJECTS_ARCHIVE";
            body = ''
              argparse a/archive -- $argv; or return 1
              set -l base $PROJECTS_HOME
              set -l dir
              if set -q _flag_archive
                set base $PROJECTS_ARCHIVE
                set dir (
                  command find "$PROJECTS_ARCHIVE" -mindepth 2 -maxdepth 2 -type d 2>/dev/null \
                  | string replace "$PROJECTS_ARCHIVE/" "" \
                  | fzf --query "$argv" --select-1 --exit-0
                )
              else
                set dir (
                  command find "$PROJECTS_HOME" -mindepth 2 -maxdepth 2 -type d \
                    -not -path "$PROJECTS_ARCHIVE/*" 2>/dev/null \
                  | string replace "$PROJECTS_HOME/" "" \
                  | fzf --query "$argv" --select-1 --exit-0
                )
              end
              if test -n "$dir"
                cd "$base/$dir"
              end
            '';
          };

          prjo = {
            description = "Jump to an org directory under $PROJECTS_HOME";
            body = ''
              set -l org (
                command find "$PROJECTS_HOME" -mindepth 1 -maxdepth 1 -type d \
                  -not -name _archive 2>/dev/null \
                | string replace "$PROJECTS_HOME/" "" \
                | fzf --query "$argv" --select-1 --exit-0
              )
              and cd "$PROJECTS_HOME/$org"
            '';
          };

          prjget = {
            description = "Clone a GitHub repo into $PROJECTS_HOME/<org>/<repo> and cd in";
            body = ''
              set -l spec $argv[1]
              if test -z "$spec"
                echo "usage: prjget <owner>/<repo> | <github-url>" >&2
                return 1
              end

              # Normalize any accepted form (owner/repo, https, ssh) to owner/repo.
              set -l slug (string replace -r '^(https?://github\.com/|git@github\.com:)' "" -- $spec)
              set slug (string replace -r '\.git$' "" -- $slug)
              set -l parts (string split "/" -- $slug)
              if test (count $parts) -lt 2
                echo "prjget: expected <owner>/<repo>, got '$spec'" >&2
                return 1
              end
              set -l owner $parts[1]
              set -l repo $parts[2]

              # Own accounts collapse into the personal self/ namespace; the clone
              # URL still uses the real owner.
              set -l org $owner
              if contains -- $owner ${selfOwnersFish}
                set org self
              end

              set -l dest "$PROJECTS_HOME/$org/$repo"
              if test -d "$dest"
                cd "$dest"
                return
              end
              command git clone "git@github.com:$owner/$repo.git" "$dest"; and cd "$dest"
            '';
          };

          prjarch = {
            description = "Archive the current project: move <org>/<repo> to $PROJECTS_ARCHIVE";
            body = ''
              set -l root (command git rev-parse --show-toplevel 2>/dev/null; or pwd)
              set -l rel (string replace "$PROJECTS_HOME/" "" -- $root)
              if test (count (string split "/" -- $rel)) -ne 2
                echo "prjarch: not in an <org>/<repo> project under \$PROJECTS_HOME: $root" >&2
                return 1
              end
              set -l dest "$PROJECTS_ARCHIVE/$rel"
              command mkdir -p (path dirname "$dest")
              command mv "$root" "$dest"
              echo "archived → $dest"
              cd "$PROJECTS_HOME"
            '';
          };

          prjunarch = {
            description = "Unarchive the current project back to $PROJECTS_HOME/<org>/<repo>";
            body = ''
              set -l root (pwd)
              set -l rel (string replace "$PROJECTS_ARCHIVE/" "" -- $root)
              if test (count (string split "/" -- $rel)) -ne 2
                echo "prjunarch: not in an <org>/<repo> project under \$PROJECTS_ARCHIVE: $root" >&2
                return 1
              end
              set -l dest "$PROJECTS_HOME/$rel"
              command mkdir -p (path dirname "$dest")
              command mv "$root" "$dest"
              echo "unarchived → $dest"
              cd "$dest"
            '';
          };
        };
      };
  };
}
