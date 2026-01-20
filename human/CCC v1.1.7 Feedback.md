# CCC v1.1.7 Feedback

#### Critical Feedback

Note: The designer has prompted Claude Code to persist Claude data by mounting Claude files.

1. Currently, there are several persisted folders which are at the global level by ccc. This means that if there are multiple projects their configurations might conflict. Re-authenticating claude code for each project is acceptable.  
   1. Please now mount these Claude persistence data to a single .ccc folder. Please include a \~/.ccc/\<project\>/claude folder to persist projects independently.  
   2. Please also change the Sandbox/ccc-secrets/\<project\> which gets mounted to the secrets directory in the container to \~/.ccc/\<project\>/sandbox-secrets  
2. Please only persist Claude information with the .ccc mounted files. Node js config should not be persisted here, it should be persisted in the sandbox if anything.  
3. The tests take too long. Please speed them up.  
4. When system changes are made and Dockerfile is modified and re-built, the name of the built image is currently different from the name of the image that is running. We want this to be the same name, so next time the container is started (ccc is run from the directory), we will automatically use the persisted image that was rebuilt.

   