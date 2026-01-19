# CCC 1.0.0 Feedback

#### Critical Feedback

Please reread Claude Code [Container.md](http://Container.md). There are a few divergances from the original spec.

1. The steering file named [CLAUDE.md](http://CLAUDE.md) is not read by the container on start.  
2. When I restart the container, I indeed to set up claude code again. This means that our sessions are not persistent.  
3. I was told “If you want this installation to persist across container rebuilds, I can add it to the Dockerfile.” Even after asking Claude to read the steering file. This decision should be made automatically. Installing software should be persisted.  
4. When I told Claude to to persist the software, it added it to the dockerfile without rebuilding the container. The specs say to use Docker in docker to attempt rebuilding the container from within docker. (restarting the container is not needed). This will fix any dockerfile issues.

#### New Features

1. Upon start I am forced to accept the dangerous permission for Claude. If possible have this confirmation automatically confirmed that I am okay with dangerous permissions as I am running from within a container.  
2. Please add a version number on the ccc startup