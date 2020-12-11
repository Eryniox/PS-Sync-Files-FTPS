#Requires -Version 5

$Invocation = (Get-Variable MyInvocation -Scope Script).Value
$CurrentFolder = (Split-Path ($Invocation.MyCommand.Path))
$configFile = "config.clixml"
If (Test-Path $CurrentFolder\$configFile -ErrorAction SilentlyContinue)
{
    $config = Import-Clixml -Path $configFile
} Else {
    $config = Import-Clixml -Path $CurrentFolder\config-default.clixml
}

