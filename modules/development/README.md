# development/

Developer tooling.

| Sub-directory | Features (from `master`'s `home/development/*`) |
|---|---|
| `ai/` | `claude-code` |
| `build/` | `bazel` |
| `database/` | `mysql` |
| `editors/` | `vscode` (today's `code`), `cursor`, `idea` |
| `languages/` | `haskell`, `java`, `scala` |
| `platforms/` | `jvm`, `node` |
| `testing/` | `testcontainers` |
| `projects/` | `projects` |

Terminal editors (`nvim`) live in `../cli/editors/`. This directory is for IDEs.

Examples:
- `home/development/editors/code` → `development/editors/vscode/`, aspect `vscode`.
- `home/development/ai/claude-code` → `development/ai/claude-code/`, aspect `claude-code`.

Rules: [../README.md](../README.md).
