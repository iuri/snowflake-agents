-- Step 1: Create a Personal Access Token (PAT) in GitHub
-- If your repository is private, Snowflake needs credentials to fetch and read the repository data.
-- 1.1. Go to your GitHub account settings and navigate to Developer Settings > Personal Access Tokens (Tokens classic).
-- 1.2. Generate a new token with the repo scope. Copy the token string.


-- Step 2: Configure the Secret in Snowflake
-- Log into your Snowflake instance (using a role with security privileges, like ACCOUNTADMIN or SECURITYADMIN) and securely store your GitHub token: 

-- 2.1. Create a database and schema to house your integration tools if you haven't already
CREATE DATABASE IF NOT EXISTS agent_governance;
CREATE SCHEMA IF NOT EXISTS agent_governance.git;

-- 2.2. Create a secret object containing your GitHub Personal Access Token
-- if the systems uses generic string auth use this query, otherwise, use uername and password (pwd is the token)
CREATE OR REPLACE SECRET agent_governance.git.github_pat_secret
  TYPE = GENERIC_STRING
  SECRET_STRING = '<github-auth-string>';


-- 2.2. Create a secret object containing your GitHub Personal Access Token
CREATE OR REPLACE SECRET agent_governance.git.github_pat_secret
  TYPE = PASSWORD
  USERNAME = '<github_user>'
  PASSWORD = '<github-token>';

-- Step 3: Create the Git API Integration
-- Now, create an API Integration that explicitly authorizes Snowflake to route network requests out to your GitHub environment
CREATE OR REPLACE API INTEGRATION github_api_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/<github_user>/<repository_name>/')
  ALLOWED_AUTHENTICATION_SECRETS = (agent_governance.git.github_pat_secret)
  ENABLED = TRUE;

-- Step 4: Map the Repository inside Snowflake
-- With permissions granted, establish a native GIT REPOSITORY object. This tells Snowflake to mirror your codebase inside your database catalog.
CREATE OR REPLACE GIT REPOSITORY agent_governance.git.my_agent_repo
  API_INTEGRATION = github_api_integration
  GIT_CREDENTIALS = agent_governance.git.github_pat_secret
  ORIGIN = 'https://github.com/<github_user>/<repository_name>.git';


-- Step 5: Synchronize and Connect to Agent Studio (Cortex Agents)
-- To pull the absolute latest state of your configuration files, models, and tools from GitHub into Snowflake's active runtime, execute a fetch:
ALTER GIT REPOSITORY agent_governance.git.my_agent_repo FETCH;




-- 2. Configure Snowflake for Tokenless OIDC (Security Best Practice)To avoid standard passwords or API token rot inside GitHub,
-- link your GitHub organization directory explicitly to your Snowflake Security cluster. 
-- Run this setup statement inside Snowflake using the ACCOUNTADMIN role:
CREATE OR REPLACE SECURITY INTEGRATION github_actions_oidc_integration
  TYPE = EXTERNAL_STAGE
  STAGE_PROVIDER = OIDC
  ENABLED = TRUE
  ISSUER = 'https://githubusercontent.com'
  AUDIENCE_LIST = ('https://github.com<your-github-organization-or-username>');
