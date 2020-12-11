#Requires -Version 5

[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSProvideDefaultParameterValue", "Version")]
$Version = 0.01

$ConfigFile = $PSScriptRoot + "\config.clixml"
$CredentialFile = $PSScriptRoot + "\ftps-credentials.clixml"

If (Test-Path -Path $ConfigFile -ErrorAction SilentlyContinue)
{
    $SFFConfig = Import-Clixml -Path $ConfigFile
} Else {
    Write-Warning "No config... Aborting..."
    Return
}

$DBFile = $PSScriptRoot + "\" + $SFFConfig.DBFileName

If (!(Test-Path -Path $SFFConfig.DBArchive -ErrorAction SilentlyContinue))
{
    mkdir $SFFConfig.DBArchive 
}

If ($DBFile -and (Test-Path -Path $DBFile -ErrorAction SilentlyContinue))
{
    $DateTime = Get-Date -Format "yyyy-MM-dd-HH-mm"
    Copy-Item -Path $DBFile -Destination ($SFFConfig.DBArchive + "\SFF-DB-" + $DateTime + ".json") -Force
    $FileFolderDB = Get-Content -Raw -Path $DBFile -Encoding UTF8 | ConvertFrom-Json
    #Import-Clixml -Path $DBFile
} Else {
    $FileFolderDB = @()
}

Function Get-PlainUsernamePassword
{
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "ConfigCredential")]
  param (
  [parameter(Mandatory=$true)]
  $ConfigCredential
  )
  $UnsecureCredential = $ConfigCredential.Clone()
  $UnsecureCredential.UserName = (New-Object PSCredential "user", ($ConfigCredential.UserName | ConvertTo-SecureString) ).GetNetworkCredential().Password

  $SecureCredential = (New-Object PSCredential $UnsecureCredential.UserName, ($UnsecureCredential.Password | ConvertTo-SecureString) )
  Return $SecureCredential
}

Function Update-SFFDataBase
{
    param (
        [parameter(Mandatory=$true)]
        $Config,
        [parameter(Mandatory=$true)]
        $Database,
        [parameter(Mandatory=$true)]
        $NewFile
        )
    $NewDBFiles = @()
    foreach ($CurrentSyncPath in $Config.SyncPathArray)
    {
        $CurrentDBFiles = $Database | Where-Object {$_.DBName -like $CurrentSyncPath.DBName}
        $CurrentLocalFiles = Get-ChildItem $CurrentSyncPath.LocalPath -Recurse -Force -File | 
            Select-Object -Property BaseName, Mode, Name, Length, DirectoryName, Directory, 
            FullName, Extension, CreationTime, LastWriteTime, 
            @{l='SyncName';e={ $_.FullName.ToString() -replace [Regex]::Escape($CurrentSyncPath.LocalPath),"" }}, 
            @{l='DBName';e={ $CurrentSyncPath.DBName }}

        $TotalCurrentFiles = $CurrentDBFiles + $CurrentLocalFiles | Sort-Object -Property SyncName -Unique
        $NewDBFiles += $TotalCurrentFiles
    }

    $NewDBFiles | ConvertTo-Json  | Set-Content -Path $NewFile -Force -Encoding UTF8
}

Update-SFFDataBase -Config $SFFConfig -Database $FileFolderDB -NewFile $DBFile
$ConfigCredential = Import-Clixml -Path $CredentialFile
$ConfigCredential = $ConfigCredential | Where-Object { $_.RunningUser -eq $env:USERNAME -and $_.Server -like $SFFConfig.Server }

If (!($ConfigCredential))
{
    Write-Warning "No credentials found... Aborting..."
    Return
}

$Credential = Get-PlainUsernamePassword -ConfigCredential $ConfigCredential 
$SFFConfig.TlsThumbPrint = $SFFConfig.TlsThumbPrint -replace " ","-"

$Splash = @{
    HostName    = $SFFConfig.Server
    Protocol    = "Ftp"
    Credential  = $Credential
    FtpSecure   = "Explicit"
    PortNumber  = $SFFConfig.Port
    TlsHostCertificateFingerprint = $SFFConfig.TlsThumbPrint
}
$sessionOption = New-WinSCPSessionOption @Splash
try {
    Update-SFFDataBase -Config $SFFConfig -Database $FileFolderDB -NewFile $DBFile
    New-WinSCPSession -SessionOption $sessionOption
    foreach ($CurrentSyncPath in $SFFConfig.SyncPathArray)
    {
        $CurrentDBFiles = $Database | Where-Object {$_.DBName -like $CurrentSyncPath.DBName}
        $CurrentDBFilesList = $CurrentDBFiles | Select-Object -ExpandProperty "SyncName"
        $CurrentRemoteFiles = Get-WinSCPChildItem -Path $CurrentSyncPath.RemotePath -File -Recurse | 
            Select-Object -Property FileType, FullName, Mode, Name, Length, LastWriteTime, 
            @{l='SyncName';e={ $_.FullName.ToString() -replace [Regex]::Escape($CurrentSyncPath.RemotePath),"" }}, 
            @{l='DBName';e={ $CurrentSyncPath.DBName }}

        foreach ($CurrentRemoteFile in $CurrentRemoteFiles)
        {
            If ($CurrentDBFilesList -notcontains ($CurrentRemoteFile.SyncName -replace [Regex]::Escape("/"),"\" )
            )
            {
                #Time to download file!:
                $DownloadPathFile = Join-Path -Path $SFFConfig.DownloadFolder -ChildPath $CurrentRemoteFile.Name
                $NewPath = $CurrentSyncPath.LocalPath + $CurrentRemoteFile.SyncName -replace [Regex]::Escape("/"),"\"
                Write-Host "Downloading: $($CurrentRemoteFile.FullName) to: $DownloadPathFile, and moving to: $NewPath"
                #$Result = Receive-WinSCPItem -RemotePath $CurrentRemoteFile.FullName -LocalPath $DownloadPathFile
                If ( $Result.IsSuccess )
                {
                    Move-Item -Path $DownloadPathFile -Destination $NewPath
                }
            }
        }
    }
    Update-SFFDataBase -Config $SFFConfig -Database $FileFolderDB -NewFile $DBFile
}
catch {
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    Write-Warning $ErrorMessage
    Write-Warning $FailedItem 
    Write-Warning "Error!... Aborting..."
    Return
}
finally {
    Remove-WinSCPSession
}
