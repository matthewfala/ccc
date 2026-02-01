# CCC - Claude Code Container

**Version 1.1.9**

A tool to run Claude Code in a sandboxed Docker container, restricting its access to only the current project directory.

## Overview

CCC (Claude Code Container) provides a secure way to use Claude Code by:

- **Sandboxing**: Restricts Claude Code to only access files in the mounted project directory (`/sandbox`)
- **Persistent Authentication**: Maintains Claude Code sign-in across sessions
- **Secrets Management**: Provides a separate mounted directory for sensitive data that shouldn't be committed to git
- **Customizable Environment**: Allows Claude Code to customize its container environment via Dockerfile modifications
- **Docker-in-Docker**: Claude Code can rebuild the container from within using the mounted Docker socket
- **Auto-confirm Permissions**: Dangerous permissions are automatically accepted since you're running in a sandbox
- **Google Drive Integration**: Automatically captures user prompts and uploads them to a Google Team Drive
- **Unique Project Identifiers**: Each project gets a unique ID (`<folder>-<8-char-hex>`) to avoid conflicts when multiple projects share the same folder name

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
curl -o ~/bin/ccc https://raw.githubusercontent.com/matthewfala/ccc/main/bin/ccc
chmod +x ~/bin/ccc

# Add to PATH if not already
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Option 3: System-wide Installation

```bash
# Requires sudo
sudo curl -o /usr/local/bin/ccc https://raw.githubusercontent.com/matthewfala/ccc/main/bin/ccc
sudo chmod +x /usr/local/bin/ccc
```

## Quick Start

```bash
# Navigate to your project directory
cd ~/projects/my-project

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
│   ├── .ccc-id                   # Unique project identifier
│   ├── Dockerfile.devcontainer   # Customize your container here
│   ├── init-firewall.sh          # Network firewall script
│   ├── entrypoint.sh             # Container initialization script
│   ├── ccc-store-prompt.sh       # Prompt capture hook (shell wrapper)
│   ├── ccc-store-prompt.py       # Prompt capture hook (Drive uploader)
│   ├── CLAUDE.md                 # Steering file for Claude Code
│   └── .gitignore                # Ignores local files
├── [your project files]
```

Additionally, on your host machine (all project data is isolated per-project using the unique identifier):

```
~/.ccc/<identifier>/
├── claude/              # Claude Code authentication & settings
├── xdg-config/          # XDG config directory
├── xdg-data/            # XDG data directory
├── claude.json          # Theme and preferences
├── sandbox-secrets/     # Persistent secrets storage
└── configuration/       # Read-only project config (mounted at /config)
    ├── project-config.json      # Project and Drive settings
    └── drive-credentials.json   # Google service account key (if configured)
```

## Container Mounts

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| Current directory | `/sandbox` | Your project files |
| `~/.ccc/<identifier>/sandbox-secrets` | `/secrets` | Persistent secrets |
| `~/.ccc/<identifier>/configuration` | `/config` (read-only) | Project config and Drive credentials |
| `~/.ccc/<identifier>/claude` | `/home/node/.claude` | Claude authentication & settings |
| `~/.ccc/<identifier>/xdg-config` | `/home/node/.config` | XDG config directory |
| `~/.ccc/<identifier>/xdg-data` | `/home/node/.local/share` | XDG data directory |
| `~/.ccc/<identifier>/claude.json` | `/home/node/.claude.json` | Theme and preferences |
| `/var/run/docker.sock` | `/var/run/docker.sock` | Docker-in-Docker |

**Note:** All persistence data is project-specific using unique identifiers, allowing multiple projects — even with the same folder name — to have independent configurations.

## Customizing the Container

Claude Code can automatically customize its environment by modifying the Dockerfile and rebuilding from within the container:

1. Claude Code edits `/sandbox/ccc/Dockerfile.devcontainer` in the container
2. Claude Code rebuilds using Docker-in-Docker: `docker build -t ccc-devcontainer-<identifier> -f Dockerfile.devcontainer .`
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

## Unique Project Identifiers

Each project gets a unique identifier in the format `<folder-name>-<8-char-hex>` (e.g., `my-project-a3f1b2c9`), generated on first `ccc init` and persisted in `ccc/.ccc-id`. This identifier is used for:

- Docker image name (`ccc-devcontainer-<identifier>`)
- Docker container name (`ccc-<identifier>`)
- Host-side persistence directory (`~/.ccc/<identifier>/`)
- Google Drive folder naming

This prevents conflicts when multiple projects share the same folder name but exist in different directories.

## Google Drive Integration

CCC can automatically capture user prompts and upload them to a Google Team Drive. This is useful for maintaining a record of all prompts sent to Claude across sessions.

### How It Works

1. A `UserPromptSubmit` hook is injected into Claude Code's settings on container startup (when Drive is enabled)
2. Each prompt is captured by `ccc-store-prompt.sh`, which runs the Python uploader in the background
3. The uploader appends the prompt to a session-specific markdown file on Google Drive
4. Each session gets a unique file: `session_<date>_<unix-timestamp>_<random>.md` (e.g., `session_2025-05-15_1715789527_a3f1b2c9.md`)
5. Multiple prompts within the same session append to the same file
6. Only user prompts are captured — model responses are not uploaded

### Setup

1. Create a Google Cloud service account with Drive API access
2. Place the service account JSON key at `~/.ccc/<identifier>/configuration/drive-credentials.json`
3. Edit `~/.ccc/<identifier>/configuration/project-config.json`:

```json
{
  "projectName": "my-project",
  "cccIdentifier": "my-project-a3f1b2c9",
  "googleDrive": {
    "enabled": true,
    "credentialsPath": "/config/drive-credentials.json",
    "documentsFolderId": "<your-documents-folder-id>",
    "promptsFolderId": "<your-prompts-folder-id>"
  }
}
```

4. The prompts folder on Drive will have a subfolder per project (using the CCC identifier), with session files inside

### Notes

- Uploads run asynchronously in the background and never block Claude
- If an upload fails, the error is logged to stderr but does not interfere with Claude Code
- A Google Workspace with Team Drive is recommended for restricted write permissions via service accounts

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

### Upgrading from v1.1.7 or earlier

If you're upgrading from an older version, your data will be automatically migrated from the old global paths to the new project-specific paths. v1.1.9 also introduces unique project identifiers and Google Drive integration — run `ccc init` to generate the identifier and configuration. If you have issues:

```bash
# Force rebuild the container to get the latest entrypoint
ccc --build
```

After verifying everything works, you can delete the old directories:
- `~/.ccc-claude-config`
- `~/.ccc-xdg-config`
- `~/.ccc-xdg-data`
- `~/.ccc-claude.json`
- `~/Sandbox/ccc-secrets/<project>`

## Security Considerations

- Claude Code runs with `--dangerously-skip-permissions` inside the container
- File access is restricted to the mounted `/sandbox` directory
- Network can be restricted using `--no-network`
- Secrets are stored separately from project files
- The container runs as non-root user `node`

## First-Time Setup

On first run, you'll need to authenticate Claude Code:

1. Start the container: `ccc`
2. When prompted with "Invalid API key", run `/login` inside the container
3. Follow the authentication flow in your browser
4. Your credentials will be saved to `~/.ccc/<identifier>/claude/` for future sessions

Each project maintains its own authentication, so you may need to authenticate once per project.

## How It Works

1. **Initialization**: Creates a `ccc/` folder with Dockerfile, hook scripts, and configuration. Generates a unique project identifier
2. **Build**: Builds a Docker image with Claude Code pre-installed
3. **Run**: Starts a container with your project mounted at `/sandbox` and configuration mounted at `/config`
4. **Authentication**: Persists Claude Code login in `~/.ccc/<identifier>/claude/`
5. **Prompt Capture**: If Google Drive is enabled, a hook captures each user prompt and uploads it asynchronously
6. **Migration**: Automatically migrates data from older ccc versions (v1.1.7 and earlier)

## Credits

**Designed by Matthew Fala**
matthewfala@gmail.com

**All Rights Reserved**
