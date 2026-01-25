# Python Development Environment Setup - MX Linux Trixie

## Prerequisites
- MX Linux Trixie (Debian 13 base)
- sudo access
- Internet connection

## Installation Steps

### 1. Update Package Lists
```bash
sudo apt update
```

### 2. Install Python Core Components
```bash
sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential
```

**What this installs:**
- `python3` - Python interpreter (likely already present)
- `python3-pip` - pip package manager (for venv use)
- `python3-venv` - Virtual environment module
- `python3-dev` - Development headers for compiling C extensions
- `build-essential` - GCC, make, and build tools

### 3. Install Additional Python Tools
```bash
sudo apt install -y python3-wheel python3-setuptools
```

**What this installs:**
- `python3-wheel` - Modern Python package format support
- `python3-setuptools` - Package development and distribution tools

### 4. Verify Python Installation
```bash
python3 --version
```
Expected: Python 3.11.x or 3.12.x

### 5. Verify pip Installation
```bash
pip3 --version
```
Expected: pip 23.x or higher

### 6. Install pipx for Managing Python CLI Tools
```bash
sudo apt install -y pipx
```

**What is pipx:**
- Installs Python CLI applications in isolated environments
- Prevents conflicts with system packages (PEP 668 compliant)
- Perfect for tools like Poetry, black, pytest, etc.

### 7. Ensure pipx PATH Configuration
```bash
pipx ensurepath
```

**What this does:** Adds `~/.local/bin` to your PATH in `~/.bashrc`

### 8. Apply PATH Changes
```bash
source ~/.bashrc
```

**Or:** Open a new terminal for changes to take effect

### 9. Install Poetry via pipx
```bash
pipx install poetry
```

**Why pipx instead of pip:**
- Poetry runs in its own isolated environment
- No conflicts with system Python packages
- Clean updates: `pipx upgrade poetry`
- This is the Debian-recommended approach

### 10. Verify Poetry Installation
```bash
poetry --version
```
Expected: Poetry version 1.8.x or higher

### 11. Configure Poetry (Recommended)
```bash
# Create virtual environments inside project directories
poetry config virtualenvs.in-project true

# Verify configuration
poetry config --list
```

**Why:** Keeps each project's dependencies isolated and easy to locate at `.venv/`

## Verification Checklist

Run these commands to confirm everything works:
```bash
# Python is available
python3 --version

# pip is available (for use in venvs)
pip3 --version

# Can create virtual environments
python3 -m venv /tmp/test-venv && rm -rf /tmp/test-venv && echo "✓ venv works"

# pipx is available
pipx --version

# Poetry is available
poetry --version

# Poetry can create projects
cd /tmp && poetry new test-project && rm -rf test-project && echo "✓ Poetry works"
```

## Quick Reference

### Creating a New Project with Poetry
```bash
# Create new project with structure
poetry new my-project
cd my-project

# Or initialize in existing directory
mkdir my-project && cd my-project
poetry init

# Add dependencies
poetry add requests pandas

# Add dev dependencies
poetry add --group dev pytest black

# Install all dependencies
poetry install

# Run Python in the virtual environment
poetry run python script.py

# Activate virtual environment shell
poetry shell

# Exit poetry shell
exit
```

### Creating Virtual Environments Manually (without Poetry)
```bash
# Create venv
python3 -m venv myenv

# Activate
source myenv/bin/activate

# Now pip works without --user flag
pip install requests

# Deactivate
deactivate
```

### Managing Global Python CLI Tools with pipx
```bash
# Install a tool
pipx install black

# List installed tools
pipx list

# Upgrade a tool
pipx upgrade poetry

# Upgrade all tools
pipx upgrade-all

# Uninstall a tool
pipx uninstall black
```

## Understanding PEP 668 (Externally Managed Environments)

**Why you can't use `pip install --user` on MX Linux:**
- Debian marks system Python as "externally managed"
- Prevents pip from accidentally breaking apt-managed packages
- Forces you to use venvs (good practice) or pipx (for tools)

**The right approach:**
- **For projects:** Use `python3 -m venv` or Poetry
- **For CLI tools:** Use `pipx install`
- **Never:** Use `sudo pip install` (breaks system)

## Troubleshooting

### "pipx: command not found" after installation
```bash
# Verify package installed
dpkg -l | grep pipx

# Re-run ensurepath
pipx ensurepath
source ~/.bashrc

# Or manually add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### "poetry: command not found" after pipx install
```bash
# Check if installed
pipx list | grep poetry

# Verify PATH includes ~/.local/bin
echo $PATH | grep .local/bin

# Re-source bashrc
source ~/.bashrc

# Or open new terminal
```

### "error: externally-managed-environment" when using pip
**This is expected behavior!** Use one of these instead:
```bash
# For project dependencies - use venv
python3 -m venv myenv
source myenv/bin/activate
pip install package-name

# For CLI tools - use pipx
pipx install package-name
```

### Poetry virtual environment issues
```bash
# Show current config
poetry config --list

# Reset to defaults
poetry config virtualenvs.in-project true
poetry config virtualenvs.create true

# Clear cache if problems persist
poetry cache clear pypi --all
```

## Updating Components

### Update system packages
```bash
sudo apt update && sudo apt upgrade
```

### Update Poetry
```bash
pipx upgrade poetry
```

### Update all pipx tools
```bash
pipx upgrade-all
```

### Update pip (inside venv only)
```bash
# Activate your venv first
source .venv/bin/activate
pip install --upgrade pip
```

## What NOT to Do

❌ `sudo pip install` - Breaks system Python packages
❌ `pip3 install --user` - Blocked by PEP 668 on Debian
❌ `pip install --break-system-packages` - Bypasses protections (use only if you know what you're doing)
❌ `apt remove python3` - Will break your system

## What TO Do

✅ Use `python3 -m venv` for project dependencies
✅ Use `pipx install` for global CLI tools
✅ Use `poetry` for project management
✅ Keep system Python untouched

## System Information

This setup assumes:
- **Init system:** systemd (MX Linux default)
- **Python version:** 3.11+ (Debian Trixie)
- **Package manager:** apt
- **Shell:** bash

## Next Steps

You now have:
- ✓ Python 3 interpreter
- ✓ pip (for venv use)
- ✓ Virtual environment support
- ✓ Build tools for compiling packages
- ✓ pipx for isolated tool installation
- ✓ Poetry for project management

Ready to create your first Python project:
```bash
poetry new awesome-project
cd awesome-project
poetry add requests
poetry install
poetry run python -c "import requests; print('It works!')"
```
