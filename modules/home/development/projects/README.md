# Projects convention

A single, mechanical layout for local checkouts under `$PROJECTS_HOME`, shared
by the primary user and the headless agent account.

## Layout

```
$PROJECTS_HOME/                 # full path, per-account (e.g. /Users/you/Projects, /home/agent/Projects)
  <org>/<repo>                  # active checkout
  self/<repo>                   # your own repos + throwaway scratch
  _archive/<org>/<repo>         # retired projects (no live remote)
```

The single rule: **an active checkout lives at `$PROJECTS_HOME/<org>/<repo>`**,
where `<org>/<repo>` is the GitHub `owner/repo`. Nothing else. Because the path
is derivable from the remote URL, no human judgement is needed to place a repo,
and both accounts resolve the same path for the same repo.

### `self/`

Repos owned by one of your own GitHub accounts collapse into `self/` instead of a
per-handle org directory. The set of "your" handles is
`nix-config.cli.tools.git.accounts` (single source of truth for identity) — so
`git@github.com:aleks-sidorenko/blog.git` → `self/blog`. Throwaway experiments
with no remote also live under `self/`.

### `_archive/`

For genuinely retired projects where the **local copy is the artifact** (no live
remote, or the remote is gone). Mirrors the same `<org>/<repo>` shape underneath.
The leading `_` is not a legal GitHub org name, so it can never collide with a
real org, and the switcher helpers never look inside it. Archiving is a human
curation act, not an automatic state.

> A repo that is merely inactive but still on GitHub is **not** archived — just
> delete the local clone. The path is re-derivable, so re-cloning is one command.

### Forks

A fork has two owners. The checkout is keyed on the **canonical/upstream org**,
not your fork — a fork of `wix/foo` lives at `wix/foo` even though you push to
your own remote. This keeps one repo in one place. (A repo you *originate* keys
to `self/` via the rule above.)

## Helpers (fish)

| Command | Action |
| --- | --- |
| `prj [-a] [query]` | fuzzy-jump to a `<org>/<repo>` checkout (`-a` searches `_archive`) |
| `prjo [query]` | fuzzy-jump to an `<org>` directory |
| `prjget <owner>/<repo>\|<url>` | clone into the derived path (own accounts → `self/`) and `cd` in |
| `prjarch` | move the current project to `_archive/<org>/<repo>` |
| `prjunarch` | move the current archived project back to `<org>/<repo>` |

## Environment

- `PROJECTS_HOME` — absolute path to the projects root (`projectsHome` option).
- `PROJECTS_ARCHIVE` — `$PROJECTS_HOME/_archive`.

Both are absolute (never `~`) so they resolve identically in interactive shells,
scripts, and non-interactive agent automation.
