## Context
Changes for 1.1.8 were iterated to completion.

## Some Feedback
1. When ccc is run on a folder, currently the container's name is ccc-<foleder name>. The image name is similar ccc-devcontainer-<folder name> This may be a problem if there are 2 folders in different locations with the same name. We prefer for this to have 2 different containers and 2 different images, and 2 different config folders. Here's the suggestion. Please persist on initial ccc a unique ccc identifier ideally in the ccc folder. This identifier should be referred to in future ccc's and be included in the image name, the container name, and the config file directories. The identifier should include the folder name and also some additional unique identifier so it is easily human readable and unique.
2. The reponame which is currently included in the project config, should be replaced with this unique identifier and the reponame should be removed from the project config. The folder that is created in the prompts should be that unique ccc identifier.

## Quest
Please implement and test the above before moving onto phase 3 of the plan.