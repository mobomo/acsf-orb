# Commands

## git-publisher

## jira-version

## blt-build
Builds the blt artifact (creates a tag and push it to Acquia repository).

This command receives a `tag` parameter which is used to se the tag name that will be created and pushed.
The default value for this tag is `build-v1.0.${CIRCLE_BUILD_NUM}`


TO-DO: Add a "segment" param to increment the tag following semantic versioning and be more flexible. 

## blt-deploy
Deploys a tag to Acquia Site Factory env using its API.


This command receives the following parameters to performs the API calls:

- tag: The tag to deploy to acsf, the default value is `build-v1.0.${CIRCLE_BUILD_NUM}`
- env: The environment where to deploy. env could be either "dev", "test", "prod", the default value is "dev"
- deploy-type: The type of deployment, could be "code" for code only, or "code, db" for the Code and Database 
  deployments.
- acsf-user: Sets the acsf user account. The username set here should have access to
- acsf-key: Sets the API Key for the user.
- acsf-site: Sets the project site. You can get this value looking at your acsf url: `https://www.[env]-[site].acsitefactory.com`


Please refer to [Acquia Site Factory API examples](https://docs.acquia.com/site-factory/extend/api/examples)
to check the update endpoint and the parameters.

## jira-transition
