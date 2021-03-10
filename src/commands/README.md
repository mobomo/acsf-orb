# Commands
The commands provided by this Orb uses the following APIs:
- Jira API with Basic Authentication
- Site Factory API

Since these APIs require an auth method, is a good practice to setup the auth/keys using Circle CI Env Variables, instead 
of adding that "sensitive" data as plain text in your config file. 

So, for the Jira basic auth, we use the `JIRA_AUTH` env var and for the Site Factory we use `ACQUIA_KEY_[ENV]` 
(ie: `ACQUIA_KEY_DEV`, or `ACQUIA_KEY_TEST`)

## git-publisher
Pushes tag to project repository.

This command receives the following parameters:

- `git-username`: The automation git username to push the tag.
- `git-email`: The automation git user email to push the tag.
- `tag`: Tag to be deployed. It's default value is `build-v1.0.${CIRCLE_BUILD_NUM}`.

## jira-version
This command creates a "version" (release) in Jira using Jira API.

Receives the following parameters:
- `tag`: The tag name to use to create the version. It's default value is `build-v1.0.${CIRCLE_BUILD_NUM}` 
- `project`: The Jira project to create the version.
- `description`: The Version description.
- `jira-url`: The Jira Cloud URL.

## blt-build
Builds the blt artifact (creates a tag and push it to Acquia repository).

This command receives a `tag` parameter which is used to se the tag name that will be created and pushed.
The default value for this tag is `build-v1.0.${CIRCLE_BUILD_NUM}`


TO-DO: Add a "segment" param to increment the tag following semantic versioning and be more flexible. 

## blt-deploy
Deploys a tag to Acquia Site Factory env using its API.


This command receives the following parameters to performs the API calls:

- `tag`: The tag to deploy to acsf, the default value is `build-v1.0.${CIRCLE_BUILD_NUM}`
- `env`: The environment where to deploy. env could be either "dev", "test", "prod", the default value is "dev"
- `deploy-type`: The type of deployment, could be "code" for code only, or "code, db" for the Code and Database 
  deployments.
- `acsf-user`: Sets the acsf user account. 
- `acsf-key`: Sets the API Key for the user.
- `acsf-site`: Sets the project site. You can get this value looking at your acsf url: `https://www.[env]-[site].acsitefactory.com`

**NOTE**: To perform API calls to the site factory is recommended to create a "machine" user in the site factory 
(in each environment!). This user should have the role "release engineer" to have the correct permissions to use the 
`update` endpoint.

Please refer to [Acquia Site Factory API examples](https://docs.acquia.com/site-factory/extend/api/examples)
to check the update endpoint and the parameters.

Site Factory API docs: https://docs.acquia.com/site-factory/extend/api

## jira-transition
Gets all tickets included between "current" deployed tag and "latest" tag, and transitions those tickets after a
successful deployment.

This command receives the following parameters:

- `tag`: The "latest" tag to be used by git log to list tickets that were included between current..latest 
  The default value is `build-v1.0.${CIRCLE_BUILD_NUM}`
- `acsf-user`: The Acquia Site Factory username.
- `acsf-key`: The Acquia Site Factory user KEY.
- `acsf-site`: The Acquia Site Factory site.
- `env`: The environment where to deploy. It's default value is "test"
- `jira-url`: The Jira Cloud URL
- `jira-transition-id`: The Jira transition ID

**NOTE:** To avoid setting the auth token in your config files, you must define it as an CircleCI Environment Variable.

Using the CircleCI UI, you can go to your Project > Project Settings > Environment Values > Add Environment Value called 
`JIRA_AUTH`

In order to encode the username:password string, you can run:
```shell
echo -n 'jira_user_email:jira_api_token' | openssl base64
```

Copy the base64 encoded string and paste it in the Environment Variable `Value` field:

![Setting CircleCI Env Vars](/assets/cci_env_vars.png)