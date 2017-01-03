[CmdletBinding()]
PARAM
(
	[Parameter(Mandatory = $true, Position = 0)]
	[String] $RepoName
	,
	[String] $RepoDescription = ''
	,
	[String] $Homepage =  ''
	,
	[String] $Org = $null
	,
	[Switch] $Private = $false
	,
	[Switch] $HasIssues = $true
	,
	[Switch] $HasWiki = $true
)

[string] $configFileName = "Config.xml";

# load config file
$here = Split-Path -Parent $MyInvocation.MyCommand.Path;
$pathToConfigFile = "$here\{0}" -f $configFileName;
[xml] $configFile = Get-Content $pathToConfigFile;

# create authentication header
$username = $configFile.Configuration.GitHub.Username;
$token = $configFile.Configuration.GitHub.Token;
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username,$token)));
$authHeader = @{"Authorization"="Basic $base64AuthInfo"};

# select .gitignore template
$gitignoreUri = 'https://api.github.com/gitignore/templates';
$gitignoreTemplates = Invoke-RestMethod -Uri $gitignoreUri -Headers $authHeader -Method Get;

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms");
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing");

$objForm = New-Object System.Windows.Forms.Form;
$objForm.Text = "Select a gitignore template";
$objForm.Size = New-Object System.Drawing.Size(300, 400);
$objForm.StartPosition = "CenterScreen";

$objForm.KeyPreview = $true;
$objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") {$x=$objListBox.SelectedItem;$objForm.Close()}});

$oKButton = New-Object System.Windows.Forms.Button;
$oKButton.Location = New-Object System.Drawing.Size(75, 320);
$oKButton.Size = New-Object System.Drawing.Size(112, 23);
$oKButton.Text = "Select";
$oKButton.Add_Click({$x=$objListBox.SelectedItem;$objForm.Close()});
$objForm.Controls.Add($oKButton);

$objLabel = New-Object System.Windows.Forms.Label;
$objLabel.Location = New-Object System.Drawing.Size(10, 20);
$objLabel.Size = New-Object System.Drawing.Size(280, 20);
$objLabel.Text = "Please select a gitignore template:";
$objForm.Controls.Add($objLabel);

$objListBox = New-Object System.Windows.Forms.ListBox;
$objListBox.Location = New-Object System.Drawing.Size(10, 40);
$objListBox.Size = New-Object System.Drawing.Size(260, 20);
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

# select license
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

$oKButton = New-Object System.Windows.Forms.Button;
$oKButton.Location = New-Object System.Drawing.Size(75,320);
$oKButton.Size = New-Object System.Drawing.Size(112,23);
$oKButton.Text = "Select";
$oKButton.Add_Click({$x=$objListBox.SelectedItem;$objForm.Close()});
$objForm.Controls.Add($oKButton);

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

# create repository
$body = @{
	name = $RepoName;
	description = $RepoDescription;
	homepage = $Homepage;
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

Start-Sleep -Seconds 3;

# add shields to README
$licenseShield = '';
if ($license -eq 'apache-2.0')
{
	$licenseShield = '[![License](https://img.shields.io/badge/license-Apache%20License%202.0-blue.svg)](https://github.com/{0}/blob/master/LICENSE)' -f $repoCreationResult.full_name;
}

$nugetVersionShield =  '[![Version](https://img.shields.io/nuget/v/{0}.svg)](https://www.nuget.org/packages/{0}/)' -f $RepoName;

$readmeUri = 'https://api.github.com/repos/{0}/readme' -f $repoCreationResult.full_name;
$readmeFile = Invoke-RestMethod -Uri $readmeUri -Headers $authHeader -Method Get;

$updatedReadme = (Get-Content $here\README_Template -Raw).replace('REPONAME', $RepoName).replace('LICENSESHIELD', $licenseShield).replace('REPODESCRIPTION', $RepoDescription).replace('NUGETVERSIONSHIELD', $nugetVersionShield);

$body = @{
	message = 'README updated';
	content = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($updatedReadme));
	sha = $readmeFile.sha;
} | ConvertTo-Json -Compress;

$contentUri = 'https://api.github.com/repos/{0}/contents/{1}' -f $repoCreationResult.full_name, $readmeFile.path;
$readmeUpdateResult = Invoke-RestMethod -Uri $contentUri -Headers $authHeader -Method Put -Body $body;
Write-Host 'Shields added to README file' -foregroundcolor "green";

# create NOTICE file
$noticeFile = (Get-Content $here\NOTICE_Template -Raw).replace('REPONAME', $RepoName).replace('REPODESCRIPTION', $RepoDescription);

$body = @{
	message = 'NOTICE file created';
	content = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($noticeFile));
} | ConvertTo-Json -Compress;

$noticeUri = 'https://api.github.com/repos/{0}/contents/NOTICE' -f $repoCreationResult.full_name;
$noticeCreationResult = Invoke-RestMethod -Uri $noticeUri -Headers $authHeader -Method Put -Body $body;
Write-Host 'NOTICE file created added to repository' -foregroundcolor "green";

# create labels
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
# Copyright 2015-2017 Marc Rufer
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

# SIG # Begin signature block
# MIIQrQYJKoZIhvcNAQcCoIIQnjCCEJoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUyWuJB+nR66/spmt4Fn9C4zuU
# +MGggg4pMIIGwzCCBaugAwIBAgIPM1H39/fXIF0HCKgJVncoMA0GCSqGSIb3DQEB
# CwUAMFgxCzAJBgNVBAYTAkNIMRUwEwYDVQQKEwxTd2lzc1NpZ24gQUcxMjAwBgNV
# BAMTKVN3aXNzU2lnbiBRdWFsaWZpZWQgUGxhdGludW0gQ0EgMjAxMCAtIEcyMB4X
# DTE1MDYwNDA3NDYzNloXDTE4MDYwNDA3NDYzNlowdjEwMC4GA1UEAxMnTWFyYyBS
# b2xhbmQgUnVmZXIgKFF1YWxpZmllZCBTaWduYXR1cmUpMSQwIgYJKoZIhvcNAQkB
# FhVtYXJjLnJ1ZmVyQGQtZmVucy5uZXQxHDAaBgNVBAUTEzEzMDAtODAxNS02Mjc5
# LTUzNjYwggEkMA0GCSqGSIb3DQEBAQUAA4IBEQAwggEMAoIBAQCh1xhH/tbJI42C
# FnkqdzxdY4BOvF8dr5zpmj+CD9CHlE4G60WvKG5zqyuh+I5mOot2GNKJ/kTgXgWh
# KKM5WevQcjrtYxV+ncqPzhMHbls4EpsG9pIR6xs35ptVrGyAexANhXyK0obaQrdF
# JTrBbUjok1fA4+vEUZXndV8371K2djlFhqoIpYWlK1kcjbA3vHrXnOo/Bkit6Zzi
# o2e++wqI8tQBamfrouxiYqUj6QjnI0DhL+GIm9exbfN8cdaC/YSe+OKR8LIhpIVY
# sgKQBdUDULBrw3N6gsHhL5D2lkf3PGagbINfGke7MNaYDFeWcyQ31Xq4QKO93/tK
# wDamACatAgUAk0y0UaOCA2gwggNkMCAGA1UdEQQZMBeBFW1hcmMucnVmZXJAZC1m
# ZW5zLm5ldDBFBgNVHRIEPjA8pDowODELMAkGA1UEBhMCQ0gxKTAnBgNVBAoTIFpl
# cnRFUyBSZWNvZ25pdGlvbiBCb2R5OiBLUE1HIEFHMA4GA1UdDwEB/wQEAwIGQDAd
# BgNVHQ4EFgQUfHnm77yKxXViaQtocqHZavb9yNwwHwYDVR0jBBgwFoAUclHgqp37
# fjhE6gJvQMifzii/HHcwgf8GA1UdHwSB9zCB9DBHoEWgQ4ZBaHR0cDovL2NybC5z
# d2lzc3NpZ24ubmV0LzcyNTFFMEFBOURGQjdFMzg0NEVBMDI2RjQwQzg5RkNFMjhC
# RjFDNzcwgaiggaWggaKGgZ9sZGFwOi8vZGlyZWN0b3J5LnN3aXNzc2lnbi5uZXQv
# Q049NzI1MUUwQUE5REZCN0UzODQ0RUEwMjZGNDBDODlGQ0UyOEJGMUM3NyUyQ089
# U3dpc3NTaWduJTJDQz1DSD9jZXJ0aWZpY2F0ZVJldm9jYXRpb25MaXN0P2Jhc2U/
# b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9uUG9pbnQwgaMGA1UdIASBmzCBmDCB
# iAYIYIV0BRoBAQEwfDBMBggrBgEFBQcCARZAaHR0cDovL3JlcG9zaXRvcnkuc3dp
# c3NzaWduLmNvbS9Td2lzc1NpZ24tUGxhdGludW0tQ1AtQ1BTLVIzLnBkZjAsBggr
# BgEFBQcCAjAgGh5TdWlzc2VJRCBxdWFsaWZpZWQgY2VydGlmaWNhdGUwCwYJYIV0
# AVkBAQEBMIHcBggrBgEFBQcBAQSBzzCBzDBkBggrBgEFBQcwAoZYaHR0cDovL3N3
# aXNzc2lnbi5uZXQvY2dpLWJpbi9hdXRob3JpdHkvZG93bmxvYWQvNzI1MUUwQUE5
# REZCN0UzODQ0RUEwMjZGNDBDODlGQ0UyOEJGMUM3NzBkBggrBgEFBQcwAYZYaHR0
# cDovL3BsYXRpbnVtLXF1YWxpZmllZC1nMi5vY3NwLnN3aXNzc2lnbi5uZXQvNzI1
# MUUwQUE5REZCN0UzODQ0RUEwMjZGNDBDODlGQ0UyOEJGMUM3NzAiBggrBgEFBQcB
# AwQWMBQwCAYGBACORgEBMAgGBgQAjkYBBDANBgkqhkiG9w0BAQsFAAOCAQEAAy21
# SJIrvwJ6Dtd4vp7GY30UiqXmb2gQ/yynWlIlsC7lRfiLjZpQCiFW00Vdi+UmN0yu
# byIH+EVCqqzkRUZmnL5/PMeN0ErCLPtcQwHpQQS3sLqL9Idn6BN1B+FV3dWv2u/T
# YKIn019hdKXqmudUGkCaqzkSOaOsL6+QgOslWsEAZooJpgFGj/evgV8UIm54sId2
# I+6L/Up/ElDWkx3njCPwTC4R2gbZBcctSumMj6n+u8JRe5xgqXnasxprtFdSzIrT
# wURn5qKE1v7aCBAjNTB6IYAzjQf0aqTAkmzx0yCVvyLkXtnZufBByuO69hMB1qve
# xUEnN2pKV9CL8uJxgzCCB14wggVGoAMCAQICEACrMs28m1mUIwT6bYTkDb0wDQYJ
# KoZIhvcNAQELBQAwSTELMAkGA1UEBhMCQ0gxFTATBgNVBAoTDFN3aXNzU2lnbiBB
# RzEjMCEGA1UEAxMaU3dpc3NTaWduIFBsYXRpbnVtIENBIC0gRzIwHhcNMTAwNDA2
# MTQwMzM0WhcNMjUwNDAyMTQwMzM0WjBYMQswCQYDVQQGEwJDSDEVMBMGA1UEChMM
# U3dpc3NTaWduIEFHMTIwMAYDVQQDEylTd2lzc1NpZ24gUXVhbGlmaWVkIFBsYXRp
# bnVtIENBIDIwMTAgLSBHMjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
# AJPzatb8VQgy6uRUIPqnGptVGe73pwmx3Evdp0tVdrgjX8hnneUTWgWMuX1ukgzF
# ApTHHzRh5TAX9sZI3utY1I5HlYIacG80olyR6aIGYwW67+Sn8uydHLojk9YjWOlz
# gF0k16uektsklLOrPXNg+koPALRtMy4B7wbNs2fHS/d+BRjf9XBv/JvkDIb5Qx72
# gJ1EyBItc1H7FkzTvrz1jjcQhX9zbefYSwhln+irEUo/MfPQM2Ur/CIeXU4iS0Mr
# 3o/X9CUTIjz2vbS9Ar2MzStrYLuQ0CXEvjWTjg0kgdIg71yPjckeQsmKSa4l7w6w
# iOk950xcs/0KWdV30/0vTjUCAwEAAaOCAzEwggMtMEUGA1UdEgQ+MDykOjA4MQsw
# CQYDVQQGFAJDSDEpMCcGA1UEChQgWmVydEVTIFJlY29nbml0aW9uIEJvZHk6IEtQ
# TUcgQUcwDgYDVR0PAQH/BAQDAgEGMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0O
# BBYEFHJR4Kqd+344ROoCb0DIn84ovxx3MB8GA1UdIwQYMBaAFFCvzAeHFUdvOMW0
# ZdHelarp35zMMIH/BgNVHR8EgfcwgfQwR6BFoEOGQWh0dHA6Ly9jcmwuc3dpc3Nz
# aWduLm5ldC81MEFGQ0MwNzg3MTU0NzZGMzhDNUI0NjVEMURFOTVBQUU5REY5Q0ND
# MIGooIGloIGihoGfbGRhcDovL2RpcmVjdG9yeS5zd2lzc3NpZ24ubmV0L0NOPTUw
# QUZDQzA3ODcxNTQ3NkYzOEM1QjQ2NUQxREU5NUFBRTlERjlDQ0MlMkNPPVN3aXNz
# U2lnbiUyQ0M9Q0g/Y2VydGlmaWNhdGVSZXZvY2F0aW9uTGlzdD9iYXNlP29iamVj
# dENsYXNzPWNSTERpc3RyaWJ1dGlvblBvaW50MIHjBgNVHSAEgdswgdgwgdUGBFUd
# IAAwgcwwTAYIKwYBBQUHAgEWQGh0dHA6Ly9yZXBvc2l0b3J5LnN3aXNzc2lnbi5j
# b20vU3dpc3NTaWduLVBsYXRpbnVtLUNQLUNQUy1SMy5wZGYwfAYIKwYBBQUHAgIw
# cBpuVGhpcyBpcyBhIGNlcnRpZmljYXRpb24gYXV0aG9yaXR5IHRoYXQgaXNzdWVz
# IHF1YWxpZmllZCBjZXJ0aWZpY2F0ZXMgYWNjb3JkaW5nIHRvIFN3aXNzIGRpZ2l0
# YWwgc2lnbmF0dXJlIGxhdy4wdAYIKwYBBQUHAQEEaDBmMGQGCCsGAQUFBzAChlho
# dHRwOi8vc3dpc3NzaWduLm5ldC9jZ2ktYmluL2F1dGhvcml0eS9kb3dubG9hZC81
# MEFGQ0MwNzg3MTU0NzZGMzhDNUI0NjVEMURFOTVBQUU5REY5Q0NDMCIGCCsGAQUF
# BwEDBBYwFDAIBgYEAI5GAQEwCAYGBACORgEEMA0GCSqGSIb3DQEBCwUAA4ICAQBy
# B1hPQRugBgIRZ4EwEyhy3ndB5Nfp1FKZYKXQwf2LI+XisneotDN3gBLXeYRY7ggQ
# M2cFeSUBH1ENAnaqX5xMBtCM5TnlJJm2gR0bRkGpYCWZamBXK+lqq+VWBdXd0pWl
# uqOU9ziVA5unRtqNifdziuWmB/d9InneJAHm7eWdVOUWVAUvwwDZLNwOjBzX22Cm
# p2rBnk1+SEQNk6Uk/f7MLxwIoWFhWbkXu+HfFLhewEl3/4nqxfv2mgmOYbWdz6ov
# rU41Cj+UJztEuXOW/kdQFAodNnfl1wTKwLSPATpC2JJovS8FeHYF7GGXT7LkRw3t
# 35WyZXqcTtrfJkNPZlaOATkhuk8cMhjsbbCqP6EoRaNRbCcAzu4e7PNLnkVxuHQq
# V5eypfy1Mc+/YloraUJBMDyadGjsoIaqi0t9WLwVAbjKrIETN0/xVJNsxN1R5V8i
# hVio4XneDBXhi6oIfbI6kr+ATUGq/qL4FQhG4baodW7DZqRZY5mEhkyr486/igh2
# Nu8bzwhzb2xQJXmPrtU04+0R3q6C7ubwFHd5GpwrEmJgwAwLupjqE0jXDfSX6i2w
# YxPKUJVDs9IpsCkyIc5U1PeKB8ZaKzYLxNaI6p4rxrUTGBxcOk+hkW+oaBScTAbH
# xGom+q40h2RADbGirC01YZBabOn9vfVTQGUw2Q4LPDGCAe4wggHqAgEBMGswWDEL
# MAkGA1UEBhMCQ0gxFTATBgNVBAoTDFN3aXNzU2lnbiBBRzEyMDAGA1UEAxMpU3dp
# c3NTaWduIFF1YWxpZmllZCBQbGF0aW51bSBDQSAyMDEwIC0gRzICDzNR9/f31yBd
# BwioCVZ3KDAJBgUrDgMCGgUAoFowGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAjBgkqhkiG9w0BCQQxFgQUNlUbDMvp
# DukTXJLpqrfkcs+nDpgwDQYJKoZIhvcNAQEBBQAEggEAHIjPrZ3mDFdoHPe3XWiy
# UG8fgk/eQITVViNgtZy7QD2r9QsTGGgJpVuBPLa//L/Rqae7nyh6XYiBbXlwamsZ
# ImulbSegXH8upkwc5V48NXrqaz2+nD2yvXD830c8PdiyOi0dxdtkMC4stpPXjtge
# uivz7QbwB9kKT3SdljaDRePnnAuv62s+S3hzD10QvbpuZfTf0oq4wwR6cIzAPKIM
# 19QVQhgVMCJQKJk6t/NXmz90H4wATIfAo6fiyLMFggYBSBLDfGXlwbLcEssLRodF
# QP4EgXXJuSRthq6tqp0mZ45tbuxfJ/1FmCBFd4kqMh4nQzpo7vyeAgX/CiC8OGa9
# Pg==
# SIG # End signature block
