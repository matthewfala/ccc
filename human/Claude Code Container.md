# Claude Code Container

#### Design

Designed by Matthew Fala  
matthewfala@gmail.com

#### Goal

I want to restrict access for Claude Code to a specific folder on my mac and not let it change any of my OS settings on the host machine.

#### Description

Create a tool called `ccc` which stands for Claude Code Container. It follows this example: [https://code.claude.com/docs/en/devcontainer](https://code.claude.com/docs/en/devcontainer)

However it mounts a /sandbox directory to the volume which mounts the current directory which the command is run in.

It also mounts a directory for persistent Claude Code sign in / session.

The command opens Claude Code from the container’s /sandbox directory and is viewed in the host’s terminal. The user can type in commands to the container from the host. Claude Code is opened in allow dangerous mode from within the container.

A steering file is added upon Claude Code startup, asking Claude Code to put any container OS changes needed for long term development (that cannot be written in the mounted folder) in the Dockerfile.devcontainer, and rebuild that image via docker in docker. Claude code should be required to continue to modify the dockerfile and rebuild the image until success.

#### /sandbox/\<project\>/ccc/Dockerfile.devcontainer

When starting up the tool ccc should build an devcontainer image if one does not exist from the dockerfile. If a Dockerfile.devcontainer does not exist in the project folder’s /ccc directory, the /ccc directory should be created and the Dockerfile.devcontainer should be made.

The default dockerfile should be: https://github.com/anthropics/claude-code/blob/main/.devcontainer/Dockerfile

By default when the container is run, there should be no restricted network access.

#### /ccc-secrets/\<project\>

The /sandbox/\<project\> directory is meant to be a git repo. Thus long term secrets shoudn’t be preserved here. For important API keys and other context which cannot be added to git, a /ccc-secrets/\<project\> directory is mounted from the \~/Sandbox/ccc-secrets/\<project\> directory on the host. Instructions are added to a claude code steering file on how to preserve information that is needed when the container dies and comes back up, via the secrets folder. This folder should be used minimally only where absolutely needed.

#### Instructions

Include readme instructions to install the tool and make it accessible with the ccc command.

#### High level objectives

The Claude Code is allowed to run dangerously but can only edit the files in the folder which the ccc command was run.

New cli tools or OS changes needed for development can be decided by Claude Code from within the container and can be preserved (so those installations do not need to occur each start up) via modifications to the dockerfile and the rebuild of the container (from within docker, via docker in docker).

#### Credits

Please include a credits section in the readme for Matthew Fala, and mentions All Rights Reserved.