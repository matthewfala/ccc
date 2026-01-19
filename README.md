# CCC - Claude Code Container

**Version 1.1.1**

A tool to run Claude Code in a sandboxed Docker container, restricting its access to only the current project directory.

## Overview

CCC (Claude Code Container) provides a secure way to use Claude Code by:

- **Sandboxing**: Restricts Claude Code to only access files in the mounted project directory (`/sandbox`)
- **Persistent Authentication**: Maintains Claude Code sign-in across sessions
- **Secrets Management**: Provides a separate mounted directory for sensitive data that shouldn't be committed to git
- **Customizable Environment**: Allows Claude Code to customize its container environment via Dockerfile modifications
- **Docker-in-Docker**: Claude Code can rebuild the container from within using the mounted Docker socket
- **Auto-confirm Permissions**: Dangerous permissions are automatically accepted since you're running in a sandbox

## Requirements

- Docker (Docker Desktop or Docker Engine)
- macOS, Linux, or Windows with WSL2
- Bash or Zsh shell

## Installation

### Option 1: Clone and Add to PATH

```bash
# Clone the repository
git clone https://github.com/your-username/ccc.git ~/ccc-tool

# Add to your shell profile (~/.bashrc, ~/.zshrc, or ~/.bash_profile)
echo 'export PATH="$HOME/ccc-tool/bin:$PATH"' >> ~/.zshrc

# Reload your shell
source ~/.zshrc
```

### Option 2: Direct Download

```bash
# Download the script
mkdir -p ~/bin
curl -o ~/bin/ccc https://raw.githubusercontent.com/your-username/ccc/main/bin/ccc
chmod +x ~/bin/ccc

# Add to PATH if not already
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Option 3: System-wide Installation

```bash
# Requires sudo
sudo curl -o /usr/local/bin/ccc https://raw.githubusercontent.com/your-username/ccc/main/bin/ccc
sudo chmod +x /usr/local/bin/ccc
```

## Quick Start

```bash
# Navigate to your project directory
cd ~/projects/my-project

# Initialize ccc (creates /ccc folder with Dockerfile)
ccc init

# Start Claude Code in container
ccc
```

## Usage

```
ccc [OPTIONS] [COMMAND]

Options:
    -h, --help          Show help message
    -v, --version       Show version information
    -b, --build         Force rebuild of the Docker image
    -n, --no-network    Restrict network access (enable firewall)
    --shell             Open a shell instead of Claude Code

Commands:
    init                Initialize ccc in current directory
    build               Build/rebuild the Docker image
    clean               Remove Docker image and container
    status              Show status of current project
```

## Examples

```bash
# Initialize a new project
ccc init

# Start Claude Code (default)
ccc

# Force rebuild the container and start
ccc --build

# Open an interactive shell in the container
ccc --shell

# Run with network restrictions
ccc --no-network

# Check project status
ccc status

# Clean up Docker resources
ccc clean
```

## Project Structure

After running `ccc init`, your project will have:

```
your-project/
├── ccc/
│   ├── Dockerfile.devcontainer   # Customize your container here
│   ├── init-firewall.sh          # Network firewall script
│   ├── CLAUDE.md                 # Steering file for Claude Code
│   └── .gitignore                # Ignores local files
├── [your project files]
```

Additionally, on your host machine:

```
~/Sandbox/ccc-secrets/<project-name>/   # Persistent secrets storage
~/.ccc-claude-config/                    # Claude Code authentication
```

## Container Mounts

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| Current directory | `/sandbox` | Your project files |
| `~/Sandbox/ccc-secrets/<project>` | `/secrets` | Persistent secrets |
| `~/.ccc-claude-config` | `/home/node/.claude` | Claude authentication |
| `~/.ccc-nodejs-config` | `/home/node/.npm` | NPM cache |
| `~/.ccc-xdg-config` | `/home/node/.config` | XDG config (Claude Code settings) |
| `~/.ccc-xdg-data` | `/home/node/.local/share` | XDG data (Claude Code data) |
| `/var/run/docker.sock` | `/var/run/docker.sock` | Docker-in-Docker |

## Customizing the Container

Claude Code can automatically customize its environment by modifying the Dockerfile and rebuilding from within the container:

1. Claude Code edits `/sandbox/ccc/Dockerfile.devcontainer` in the container
2. Claude Code rebuilds using Docker-in-Docker: `docker build -t ccc-devcontainer-<project> -f Dockerfile.devcontainer .`
3. If the build fails, Claude Code fixes the Dockerfile and retries

**Note:** This happens automatically! When Claude Code installs software, it should persist those changes to the Dockerfile and rebuild without asking.

### Example: Adding Python

```dockerfile
# Add to Dockerfile.devcontainer
RUN apt-get update && apt-get install -y python3 python3-pip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
```

## Secrets Management

The `/secrets` directory is mounted separately for storing sensitive data:

- **API Keys**: Store in `/secrets/.env` or `/secrets/api-keys.json`
- **Credentials**: Store in `/secrets/credentials/`
- **Config files with secrets**: Store in `/secrets/config/`

These files persist across container restarts and are not part of your git repository.

## Network Restrictions

By default, network access is unrestricted. Use `--no-network` to enable firewall restrictions:

```bash
ccc --no-network
```

When enabled, only these domains are accessible:
- api.anthropic.com (Claude API)
- github.com (Git operations)
- registry.npmjs.org (npm packages)
- sentry.io, statsig.com (Telemetry)
- VS Code marketplace (Extensions)

## Troubleshooting

### Docker not running

```
[ERROR] Docker daemon is not running
```

Start Docker Desktop or the Docker daemon.

### Permission denied

```
permission denied while trying to connect to the Docker daemon socket
```

Add your user to the docker group:
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

### Container build fails

Try cleaning and rebuilding:
```bash
ccc clean
ccc --build
```

### Can't access files

Ensure you're running `ccc` from within your project directory. The current directory is mounted as `/sandbox`.

## Security Considerations

- Claude Code runs with `--dangerously-skip-permissions` inside the container
- File access is restricted to the mounted `/sandbox` directory
- Network can be restricted using `--no-network`
- Secrets are stored separately from project files
- The container runs as non-root user `node`

## How It Works

1. **Initialization**: Creates a `ccc/` folder with Dockerfile and configuration
2. **Build**: Builds a Docker image with Claude Code pre-installed
3. **Run**: Starts a container with your project mounted at `/sandbox`
4. **Authentication**: Persists Claude Code login in `~/.ccc-claude-config`

## Credits

**Designed by Matthew Fala**
matthewfala@gmail.com

**All Rights Reserved**

---

For more information about Claude Code, visit: https://code.claude.ai/docs
