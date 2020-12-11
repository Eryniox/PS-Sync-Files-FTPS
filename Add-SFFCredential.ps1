#Requires -Version 5

[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSProvideDefaultParameterValue", "Version")]
$Version = 0.01
$CredentialFile = $PSScriptRoot + "\ftps-credentials.clixml"

$UnsecuredCredential = @{
    Server   = "ftps.notaserver.example.com"
    UserName = "NotReally"
    Password = "N3verM1nd"
}

Function Start-EncodeJob
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $ToEncode
    )

        Return $($ToEncode | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString)
}

If (Test-Path -Path $CredentialFile)
{
  $CurrentSecureCredentials = Import-Clixml -Path $CredentialFile
} Else {
  $CurrentSecureCredentials = @()
}

$SecuredCredential = @{
    Server   = $UnsecuredCredential.Server
    RunningUser = $env:USERNAME
    UserName = Start-EncodeJob -ToEncode $UnsecuredCredential.UserName
    Password = Start-EncodeJob -ToEncode $UnsecuredCredential.Password
}

$NewSecuredCredentials = @()
$NewSecuredCredentials += $CurrentSecureCredentials | Where-Object { 
    $_.Server -notlike $SecuredCredential.Server -and $_.RunningUser -notlike $SecuredCredential.RunninUser } 
$NewSecuredCredentials += $SecuredCredential

$NewSecuredCredentials | Export-Clixml -Path $CredentialFile
