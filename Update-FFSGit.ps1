#Requires -Version 5
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $WorkingDir
)

#cd "C:\plex\Scripts\PS-Sync-Files-FTPS"
Set-Location -Path $WorkingDir
git fetch
git reset --hard "@{u}"
git clean -df
#git pull --ff-only
git pull
