# PS.GitHub.RepoCreator
[![License](https://img.shields.io/badge/license-Apache%20License%202.0-blue.svg)](https://github.com/rufer7/PS.GitHub.RepoCreator/blob/master/LICENSE)

PowerShell script for automated repository creation and initialization

# How to use

1. Create an access token for command-line use (For details see [here](https://help.github.com/articles/creating-an-access-token-for-command-line-use/))
  1. Necessary scopes
    * `repo`
    * `write:org` (For creation of repos for an organization)
2. Check out the sources from the [`PS.GitHub.RepoCreator`](https://github.com/rufer7/PS.GitHub.RepoCreator) repository
3. Navigate to the `src` folder
  1. `Config.xml`: Fill in your GitHub username and the access token generated in step 1
  2. `NOTICE_Template`: Adjust the content according your wishes (**IMPORTANT**: The placeholders `REPONAME` and `REPODESCRIPTION` always have to occur at least once in the file)
  3. `README_Template`: Adjust the content according your wishes (**IMPORTANT**: The placeholders `REPONAME`, `LICENSESHIELD`, `NUGETDOWNLOADSSHIELD`, `NUGETVERSIONSHIELD` and `REPODESCRIPTION` always have to occur at least once in the file)
4. Now you're ready to execute the script which will do the following
  1. Creation of a new repository with the selected license and the selected gitignore file
  2. In case you selected `Apache 2.0` as license, it will add a license badge to the README file
  3. Creation of a NOTICE file based on the `NOTICE_Template`
  4. Creation of 3 new issue labels: `feature`, `onhold`, `task`

Sample invocation

```
PS C:\PS.GitHub.RepoCreator\src> .\New-GitHubRepo.ps1 -RepoName 'NAME' -RepoDescription 'DESCRIPTION'
```

## Config.xml

```
<?xml version="1.0"?>
<Configuration>
	<GitHub>
		<Username>USERNAME</Username>
		<Token>TOKEN</Token>
	</GitHub>
</Configuration>
```
