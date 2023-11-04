#Requires -Version 5
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $WorkingDir
)

#Example Scheduled task: 
#<Command>C:\WINDOWS\system32\WindowsPowerShell\v1.0\powershell.exe</Command>
#<Arguments>-ExecutionPolicy Bypass -File "C:\Scripts\PS-Sync-Files-FTPS\Update-FFSGit.ps1" -WorkingDir "C:\Scripts\PS-Sync-Files-FTPS"
#<WorkingDirectory>C:\Scripts</WorkingDirectory>

#cd "C:\plex\Scripts\PS-Sync-Files-FTPS"
Set-Location -Path $WorkingDir
git fetch
git reset --hard "@{u}"
git clean -df
#git pull --ff-only
git pull
