# codx-scripts

A centralized repository of shared shell scripts for all team repositories.

Developers install a single `codx` alias once. From that point, any script in this repo is available everywhere — no copying, no syncing, no submodules.

### WARNING

**This is a public repository, absolutly no secrets of any kind may ever be used in this repo. If a script requires secrets then it doesn't belong here, take it somewhere else.**

---

## How it works

```
Developer shell  →  codx alias  →  codx.sh (this repo)  →  scripts/<name>.sh
```

The `codx` alias fetches and executes `codx.sh` via `curl`. `codx.sh` validates the requested script name, checks it exists (HTTP 200), then fetches and executes it — all in a single pipeline. No files are written to disk on the developer's machine.

The repo is **public** so `curl` over raw HTTPS works without tokens. Write access is protected via branch protection rules and `CODEOWNERS`.

---

## Developer onboarding (one-time)

Paste this into a terminal — works on **macOS, Linux, Git Bash, and WSL**:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Co-Dx/codx_scripts/main/install.sh)
```

Then activate the alias in the current shell:

```bash
source ~/.zshrc        # zsh (macOS default)
# or
source ~/.bashrc       # bash (Linux / Git Bash / WSL)
# or
source ~/.bash_profile # bash (macOS login shell)
```

### What the installer does

1. Detects your shell (`zsh` / `bash`) and the appropriate profile file.
2. Appends the `codx` alias (idempotent — safe to run again on updates).
3. Prints the `source` command to activate immediately.

---

## Usage

```bash
codx <script-name> [args...]
```

### Built-in commands

| Command | Description |
|---|---|
| `codx list` | List all available scripts |
| `codx version` | Show the repo's current version |
| `codx update` | Re-run the installer to refresh the alias |
| `codx help` | Show usage |

## Adding a new script

1. Create `scripts/your-script.sh`.
2. Open a PR against `main`.
3. A `CODEOWNERS` review is required before merge.
4. Once merged, `codx your-script` works for everyone immediately — no install step needed.

---

## Configuration

The alias URL can be overridden via environment variables (useful for testing a fork):

```bash
export CODX_ORG=your-fork-org
export CODX_REPO=codx-scripts-dev
export CODX_BRANCH=feature/my-branch
codx yourScript --dry-run
```

---

## Repository security model

| Layer | Mechanism |
|---|---|
| Public read | Repo is public — `curl` works without tokens |
| Protected writes | `main` branch requires PR + passing checks; direct push is blocked |
| Mandatory review | `CODEOWNERS` requires approval from repo owners on all changes |
| Audit trail | All changes go through PRs with full diff history |

---