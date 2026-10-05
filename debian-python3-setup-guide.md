# Python Development Environment Setup - MX Linux Trixie

**Default tool: [uv](https://docs.astral.sh/uv/).** One binary replaces
`venv` + `pip`, `pipx`, Poetry, and pyenv, and it never touches the system
Python — so PEP 668 stops being something you fight.

| Job | Old way | uv way |
| :--- | :--- | :--- |
| Project + lockfile | `poetry new` / `poetry add` | `uv init` / `uv add` (`uv.lock`) |
| Run in the project env | `poetry run` / `source .venv/bin/activate` | `uv run` |
| Global CLI tools | `pipx install` | `uv tool install` |
| One-off tool run | `pipx run` | `uvx` |
| Other Python versions | pyenv / deadsnakes | `uv python install` |
| Plain venv + pip | `python3 -m venv` + `pip` | `uv venv` + `uv pip` |

Poetry still works and is covered in the
[appendix](#appendix-existing-poetry-projects) for projects that already use it.

## Prerequisites
- MX Linux Trixie (Debian 13 base)
- sudo access
- Internet connection

## Installation Steps

### 1. Update Package Lists
```bash
sudo apt update
```

### 2. Install the System Python and Build Tools
```bash
sudo apt install -y python3 python3-venv python3-dev build-essential curl
```

**What this installs:**
- `python3` - System interpreter (already present; apt tools depend on it)
- `python3-venv` - `python3 -m venv`, for scripts and tools that expect it
- `python3-dev` - Headers for compiling C extensions against the system Python
- `build-essential` - GCC, make, and build tools for packages without wheels
- `curl` - Needed by the uv installer

You do **not** need `python3-pip`, `python3-wheel`, or `python3-setuptools`.
uv resolves and installs packages itself, and build backends pull in
`setuptools`/`wheel` inside an isolated build environment.

### 3. Verify the System Python
```bash
python3 --version
```
Expected: Python 3.13.x (Trixie's system Python)

### 4. Install uv
Debian Trixie does not package uv. Use Astral's standalone installer:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**What this does:** Installs `uv` and `uvx` to `~/.local/bin` and adds that
directory to your PATH in your shell profile. No sudo, nothing in `/usr`.

**Prefer not to pipe to sh?** Download first and read it, or install through
apt's pipx instead:
```bash
sudo apt install -y pipx
pipx ensurepath
pipx install uv
```
(With the pipx route, upgrade with `pipx upgrade uv` — `uv self update` only
works for the standalone installer.)

### 5. Apply PATH Changes
```bash
source ~/.bashrc
```

**Or:** Open a new terminal for changes to take effect

### 6. Verify uv
```bash
uv --version
```
Expected: uv 0.10.x or higher

### 7. Enable Shell Completion (Optional)
```bash
echo 'eval "$(uv generate-shell-completion bash)"' >> ~/.bashrc
echo 'eval "$(uvx --generate-shell-completion bash)"' >> ~/.bashrc
source ~/.bashrc
```

## Verification Checklist

Run these commands to confirm everything works:
```bash
# System Python is available
python3 --version

# uv is available
uv --version

# uv can create and run a project
cd /tmp && uv init uv-test && cd uv-test \
  && uv add requests \
  && uv run python -c "import requests; print('✓ uv works')" \
  && cd /tmp && rm -rf uv-test

# uvx can run a tool without installing it
uvx ruff --version
```

## Quick Reference

### Creating a New Project
```bash
# Create a new project (pyproject.toml, .python-version, main.py, git repo)
uv init my-project
cd my-project

# Or initialize in an existing directory
uv init

# Add dependencies (creates .venv/ and uv.lock on first use)
uv add requests pandas

# Add dev dependencies
uv add --dev pytest ruff

# Remove a dependency
uv remove pandas

# Install exactly what uv.lock says (e.g. after git clone)
uv sync

# Run Python or any command in the project environment
uv run python main.py
uv run pytest

# Upgrade locked versions
uv lock --upgrade
```

No activation step is needed — `uv run` syncs the environment and runs inside
it. If you want an activated shell anyway:
```bash
source .venv/bin/activate
deactivate
```

Commit `pyproject.toml`, `uv.lock`, and `.python-version`. Do not commit `.venv/`.

### Single-File Scripts
uv can run a script with its own dependencies, no project needed:
```bash
uv init --script fetch.py
uv add --script fetch.py requests
uv run fetch.py
```
The dependencies live in a comment block at the top of the file (PEP 723).

### Using a Different Python Version
```bash
# See what's installed and available
uv python list

# Install another version (downloaded to ~/.local/share/uv/python)
uv python install 3.12

# Pick the version when creating the project
uv init --python 3.12 my-project

# Or move an existing project to a newer version (writes .python-version)
uv python pin 3.14
```
These are standalone builds. They never replace or modify `/usr/bin/python3`.

**Pinning to an *older* version fails** on a project made with the default
3.13: `uv init` writes `requires-python = ">=3.13"` into `pyproject.toml`, and
uv refuses a pin outside that range. Lower `requires-python` first, or create
the project with `--python` as above.

### Plain venv + pip (Without a Project)
```bash
# Create venv
uv venv myenv

# Install into it
uv pip install --python myenv requests

# Or activate it and use uv pip directly
source myenv/bin/activate
uv pip install requests
deactivate
```

### Managing Global Python CLI Tools
```bash
# Install a tool (isolated env, executable on PATH)
uv tool install ruff

# Run a tool once without installing it
uvx ruff check .

# List installed tools
uv tool list

# Upgrade a tool
uv tool upgrade ruff

# Upgrade all tools
uv tool upgrade --all

# Uninstall a tool
uv tool uninstall ruff
```

## Understanding PEP 668 (Externally Managed Environments)

**Why you can't use `pip install --user` on MX Linux:**
- Debian marks system Python as "externally managed"
- Prevents pip from accidentally breaking apt-managed packages
- Forces you to use venvs (good practice) or isolated tool installs

**The right approach:**
- **For projects:** `uv init` / `uv add` / `uv run`
- **For CLI tools:** `uv tool install`
- **Never:** `sudo pip install` (breaks system)

uv respects PEP 668 too — `uv pip install --system` refuses to write into the
system Python. That refusal is correct; use a project or a venv instead.

## Troubleshooting

### "uv: command not found" after installation
```bash
# Check the binary exists
ls -l ~/.local/bin/uv

# Re-source bashrc, or open a new terminal
source ~/.bashrc

# Or manually add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### "error: externally-managed-environment"
**This is expected behavior!** It means something called `pip` against the
system Python. Use one of these instead:
```bash
# For project dependencies
uv add package-name

# For a standalone venv
uv venv && uv pip install package-name

# For CLI tools
uv tool install package-name
```

### A tool installed with `uv tool install` is not on PATH
```bash
# Shows where tool executables go (normally ~/.local/bin)
uv tool dir --bin

# Adds that directory to your shell profile
uv tool update-shell
```

### A package fails to build (missing headers)
uv uses prebuilt wheels when they exist. When it must compile from source it
needs a compiler and the library's dev headers:
```bash
sudo apt install -y build-essential python3-dev
# plus the library's -dev package, e.g. libpq-dev for psycopg, libffi-dev for cffi
```
If the project uses a uv-managed Python rather than the system one,
`python3-dev` isn't needed — uv's Python builds ship their own headers.

### Environment looks wrong or stale
```bash
# Rebuild .venv from uv.lock
rm -rf .venv && uv sync

# Clear the cache if downloads are corrupt
uv cache clean
```

## Updating Components

### Update system packages
```bash
sudo apt update && sudo apt upgrade
```

### Update uv
```bash
uv self update        # standalone installer
pipx upgrade uv       # if installed through pipx
```

### Update all uv-managed tools
```bash
uv tool upgrade --all
```

### Update a project's dependencies
```bash
uv lock --upgrade && uv sync
```

### Update uv-managed Python versions
```bash
uv python upgrade
```

## What NOT to Do

❌ `sudo pip install` - Breaks system Python packages
❌ `pip3 install --user` - Blocked by PEP 668 on Debian
❌ `pip install --break-system-packages` - Bypasses protections (use only if you know what you're doing)
❌ `apt remove python3` - Will break your system
❌ `sudo` with any `uv` command - uv is per-user; root-owned files in `~/.local` or `.venv/` cause permission errors later

## What TO Do

✅ Use `uv init` / `uv add` / `uv run` for projects
✅ Use `uv tool install` (or `uvx`) for CLI tools
✅ Use `uv python install` when you need a version other than 3.13
✅ Commit `uv.lock` so installs are reproducible
✅ Keep system Python untouched

## System Information

This setup assumes:
- **Init system:** systemd (MX Linux default)
- **System Python:** 3.13 (Debian Trixie)
- **Package manager:** apt (system), uv (everything Python)
- **Shell:** bash

## Next Steps

You now have:
- ✓ System Python 3 interpreter (left alone)
- ✓ Build tools for compiling packages
- ✓ uv for projects, tools, venvs, and Python versions

Ready to create your first Python project:
```bash
uv init awesome-project
cd awesome-project
uv add requests
uv run python -c "import requests; print('It works!')"
```

---

## Appendix: Existing Poetry Projects

Use this when a project already has a `poetry.lock` and you need to keep it
on Poetry. For new work, use uv.

### Install Poetry
```bash
uv tool install poetry
poetry --version
```
Expected: Poetry 2.x

### Configure in-project venvs
```bash
poetry config virtualenvs.in-project true
```

### Common commands
```bash
poetry install                     # install from poetry.lock
poetry add requests                # add a dependency
poetry add --group dev pytest      # add a dev dependency
poetry run python script.py        # run in the project env
eval "$(poetry env activate)"      # activate the env in this shell
```

**`poetry shell` is gone.** Poetry 2.0 removed it; running it now prints
"Looks like you're trying to use a Poetry command that is not available."
Use `eval "$(poetry env activate)"` or install `poetry-plugin-shell`.

### Update Poetry
```bash
uv tool upgrade poetry
```

### Moving a project from Poetry to uv
Poetry 2 projects keep dependencies in the standard `[project]` table of
`pyproject.toml`, which uv reads directly:
```bash
uv lock     # creates uv.lock from pyproject.toml
uv sync
```
Older Poetry 1.x projects (`[tool.poetry.dependencies]`) need their
dependencies moved to `[project]` first. Check the result before deleting
`poetry.lock`.

---

## Related guides in this repo

- [MX 25 First 10 Minutes](mx25-first-10-minutes.md) — run this first on a fresh install
- [Docker Setup](debian-docker-setup-guide.md) — the other way to isolate a runtime

[Back to the repository index](README.md)
