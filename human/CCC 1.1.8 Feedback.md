Hi you're working on the ccc upstream repo, which creates the container we're working in. I just had a session on docs-integration, and included the outcome files in the docs-integration folder. All context needed to incorperate to this project are in the bootstrap file. Please don't make any changes, yet, however, I'd like to work with you on making these changes. Would you please analyze the files? Essentially, I want to
1. Create a repo level configuration which is configured outside of the repository in the .ccc repository directory. This should be in a new folder called configuration.
2. The configuration should contain the folder id to be used by the service role for viewing documents relavant to the project, the folder id which the prompt sessions should be uploaded to <project>/prompts/<repository>/session_<date>.md in the format already tested.
3. Mount the configuration folder as a view only directory
4. Instead of relying on steering to persist the prompts make a hook, which can persist the prompts and upload to google drive asynchronously.

Please work with me to create a detailed plan.

## Additional Thoughts
- The drive credentials files should be stored in the configuration directory rather than the secrets directory.
- I want to have restricted write permission, which the previous session instructed me is only possible with Team Drive in a google workspace, I'd like to work through setting this up instead of the current OAuth scheme.

## Responses to Concerns
Please init the hook before sending the prompt sending to Claude. Please see the example session included, no model response should be included in the file. Please upload immediately and don't block if fails. We need to find a way to run the upload script while claude is processing response this will avoid having additional latency for responses while the script is running.

For drive, let's set that part up first so we can test the integration. Then let's set this up locally. And finally, let's set it up in the master CCC project so we can utilize the system in any CCC instance.