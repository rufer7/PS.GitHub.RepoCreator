[CmdletBinding()]
PARAM
(
	[Parameter(Mandatory=$true)]
	[String] $RepoName
	,
	[String] $RepoDescription = ''
	,
	[String] $Org = $null
	,
	[Switch] $Private = $false
	,
	[Switch] $HasIssues = $true
	,
	[Switch] $HasWiki = $true
)

$ErrorActionPreference = "Stop"

# Create authentication header
$here = Split-Path -Parent $MyInvocation.MyCommand.Path;
[xml]$ConfigFile = Get-Content "$here\Config.xml";
$username = $ConfigFile.Configuration.GitHub.Username;
$token = $ConfigFile.Configuration.GitHub.Token;
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username,$token)));
$authHeader = @{"Authorization"="Basic $base64AuthInfo"};

# Select .gitignore template
$gitignoreUri = 'https://api.github.com/gitignore/templates';
$gitignoreTemplates = Invoke-RestMethod -Uri $gitignoreUri -Headers $authHeader -Method Get;

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms");
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing");

$objForm = New-Object System.Windows.Forms.Form;
$objForm.Text = "Select a gitignore template";
$objForm.Size = New-Object System.Drawing.Size(300,400);
$objForm.StartPosition = "CenterScreen";

$objForm.KeyPreview = $true;
$objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") {$x=$objListBox.SelectedItem;$objForm.Close()}});

$OKButton = New-Object System.Windows.Forms.Button;
$OKButton.Location = New-Object System.Drawing.Size(75,320);
$OKButton.Size = New-Object System.Drawing.Size(112,23);
$OKButton.Text = "Select";
$OKButton.Add_Click({$x=$objListBox.SelectedItem;$objForm.Close()});
$objForm.Controls.Add($OKButton);

$objLabel = New-Object System.Windows.Forms.Label;
$objLabel.Location = New-Object System.Drawing.Size(10,20);
$objLabel.Size = New-Object System.Drawing.Size(280,20);
$objLabel.Text = "Please select a gitignore template:";
$objForm.Controls.Add($objLabel);

$objListBox = New-Object System.Windows.Forms.ListBox;
$objListBox.Location = New-Object System.Drawing.Size(10,40);
$objListBox.Size = New-Object System.Drawing.Size(260,20);
$objListBox.Height = 280;

foreach ($gitignore in $gitignoreTemplates) 
{
	[void] $objListBox.Items.Add($gitignore);
}

$objForm.Controls.Add($objListBox) ;
$objForm.Topmost = $true;
$objForm.Add_Shown({$objForm.Activate()});
[void] $objForm.ShowDialog();

$gitignoreTemplate = $objListBox.Items[$objListBox.SelectedIndex];

Write-Host ('Selected gitignore template: {0}' -f $gitignoreTemplate) -foregroundcolor "green";

# Select license
# To access the API during the preview period, you must provide a custom media type in the Accept header (application/vnd.github.drax-preview+json)
$licenseUri = 'https://api.github.com/licenses';
$acceptHeader = @{"Accept"="application/vnd.github.drax-preview+json"};
$licenses = Invoke-RestMethod -Uri $licenseUri -Headers $acceptHeader -Method Get;

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms");
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing");

$objForm = New-Object System.Windows.Forms.Form;
$objForm.Text = "Select a license";
$objForm.Size = New-Object System.Drawing.Size(300,400);
$objForm.StartPosition = "CenterScreen";

$objForm.KeyPreview = $true;
$objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") {$x=$objListBox.SelectedItem;$objForm.Close()}});

$OKButton = New-Object System.Windows.Forms.Button;
$OKButton.Location = New-Object System.Drawing.Size(75,320);
$OKButton.Size = New-Object System.Drawing.Size(112,23);
$OKButton.Text = "Select";
$OKButton.Add_Click({$x=$objListBox.SelectedItem;$objForm.Close()});
$objForm.Controls.Add($OKButton);

$objLabel = New-Object System.Windows.Forms.Label;
$objLabel.Location = New-Object System.Drawing.Size(10,20);
$objLabel.Size = New-Object System.Drawing.Size(280,20);
$objLabel.Text = "Please select a license template:";
$objForm.Controls.Add($objLabel);

$objListBox = New-Object System.Windows.Forms.ListBox;
$objListBox.Location = New-Object System.Drawing.Size(10,40);
$objListBox.Size = New-Object System.Drawing.Size(260,20);
$objListBox.Height = 280;

foreach ($license in $licenses) 
{
	[void] $objListBox.Items.Add($license.name);
}

$objForm.Controls.Add($objListBox);
$objForm.Topmost = $true;
$objForm.Add_Shown({$objForm.Activate()});
[void] $objForm.ShowDialog();

$license = $licenses[$objListBox.SelectedIndex].key;

Write-Host ('Selected license template: {0}' -f $license) -foregroundcolor "green";

# Create repository
$body = @{
	name = $RepoName;
	description = $RepoDescription;
	private = $Private.IsPresent;
	has_issues = $HasIssues.IsPresent;
	has_wiki = $HasWiki.IsPresent;
	has_downloads = $true;
	auto_init = $true;
	gitignore_template = $gitignoreTemplate;
	license_template = $license;
} | ConvertTo-Json -Compress;

if($Org) 
{
	$creationUri = 'https://api.github.com/orgs/{0}/repos' -f $Org;
}
else 
{
	$creationUri = 'https://api.github.com/user/repos';
}
$repoCreationResult = Invoke-RestMethod -Uri $creationUri -Headers $authHeader -Method Post -Body $body;
Write-Host ("Repository '{0}' created" -f $RepoName) -foregroundcolor "green";

# Add license badge to README
$readmeUri = 'https://api.github.com/repos/{0}/readme' -f $repoCreationResult.full_name;
if ($license -eq 'apache-2.0')
{
	$readmeFile = Invoke-RestMethod -Uri $readmeUri -Headers $authHeader -Method Get;
	
	$licenseBadge = '[![License](https://img.shields.io/badge/license-Apache%20License%202.0-blue.svg)](https://github.com/{0}/blob/master/LICENSE)' -f $repoCreationResult.full_name;
	$updatedReadme = (Get-Content $here\README_Template -Raw).replace('REPONAME', $RepoName).replace('LICENSEBADGE', $licenseBadge).replace('REPODESCRIPTION', $RepoDescription);
	
	$body = @{
		message = 'README updated';
		content = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($updatedReadme));
		sha = $readmeFile.sha;
	} | ConvertTo-Json -Compress;
	
	$contentUri = 'https://api.github.com/repos/{0}/contents/{1}' -f $repoCreationResult.full_name, $readmeFile.path;
	$readmeUpdateResult = Invoke-RestMethod -Uri $contentUri -Headers $authHeader -Method Put -Body $body;
	Write-Host 'License badge added to README file' -foregroundcolor "green";
}

# Create NOTICE file
$noticeFile = (Get-Content $here\NOTICE_Template -Raw).replace('REPONAME', $RepoName).replace('REPODESCRIPTION', $RepoDescription);

$body = @{
	message = 'NOTICE file created';
	content = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($noticeFile));
} | ConvertTo-Json -Compress;

$noticeUri = 'https://api.github.com/repos/{0}/contents/NOTICE' -f $repoCreationResult.full_name;
$noticeCreationResult = Invoke-RestMethod -Uri $noticeUri -Headers $authHeader -Method Put -Body $body;
Write-Host 'NOTICE file created added to repository' -foregroundcolor "green";

# Create labels
$labelUri = 'https://api.github.com/repos/{0}/labels' -f $repoCreationResult.full_name;

$body = @{
	name = "feature";
	color = "fbca04"
} | ConvertTo-Json -Compress;

$labelCreationResult = Invoke-RestMethod -Uri $labelUri -Headers $authHeader -Method Post -Body $body;
Write-Host 'Feature label added to repository' -foregroundcolor "green";

$body = @{
	name = "onhold";
	color = "fad8c7"
} | ConvertTo-Json -Compress;

$labelCreationResult = Invoke-RestMethod -Uri $labelUri -Headers $authHeader -Method Post -Body $body;
Write-Host 'onhold label added to repository' -foregroundcolor "green";

$body = @{
	name = "task";
	color = "0052cc"
} | ConvertTo-Json -Compress;

$labelCreationResult = Invoke-RestMethod -Uri $labelUri -Headers $authHeader -Method Post -Body $body;
Write-Host 'task label added to repository' -foregroundcolor "green";

#
# Copyright 2015 Marc Rufer
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
