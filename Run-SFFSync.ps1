#Requires -Version 5

#<Command>C:\WINDOWS\system32\WindowsPowerShell\v1.0\powershell.exe</Command>
#<Arguments>-ExecutionPolicy Bypass -File "C:\Scripts\PS-Sync-Files-FTPS\Run-SFFSync.ps1"
#<WorkingDirectory>C:\Scripts\PS-Sync-Files-FTPS

[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSProvideDefaultParameterValue", "Version")]
$Version = 0.06

$ConfigFile = $PSScriptRoot + "\config.clixml"
$CredentialFile = $PSScriptRoot + "\ftps-credentials.clixml"

$Blacklist = @("*\Kaptein Sabeltann - Hidden\*",
    "*\Dave.Chappelle-The.Kennedy.Center.Mark.Twain.Prize.for.American.Humor.2020.NORDIC.720p.NF.WEBRIP.DD.5.1.h264-FULLTUMMY\*")
#
$DownloadFolderMinimumFreeSpace = 80GB


If (Test-Path -Path $ConfigFile -ErrorAction SilentlyContinue)
{
    $SFFConfig = Import-Clixml -Path $ConfigFile
} Else {
    Write-Warning "No config... Aborting..."
    Return
}

If ($SFFConfig.DownloadFolder -and (Test-Path -Path $SFFConfig.DownloadFolder -ErrorAction SilentlyContinue) )
{
    $DeletePartialDownloads = Get-ChildItem -Path $SFFConfig.DownloadFolder
    foreach ($DeleteFile in $DeletePartialDownloads)
    {
        Remove-Item -Path $DeleteFile.FullName
    }
} Else {
    Write-Warning "No Download-folder! Aborting..."
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

Function Get-FreeSpace {
    param ([string]$Path)
    $Volume = Get-Volume -FilePath $Path
    If ($Volume) { Return $Volume.SizeRemaining }

    $DriveSpace =  Get-CimInstance -Class Win32_LogicalDisk | Where-Object {$_.DeviceID -like ($Path.Substring(0,1)) }
    If ($DriveSpace) { Return $DriveSpace.FreeSpace }

    # Determine all single-letter drive names.
    $takenDriveLetters = (Get-PSDrive).Name -like '?'

    # Find the first unused drive letter.
    # Note: In PowerShell (Core) 7+ you can simplify [char[]] (0x41..0x5a) to
    #       'A'..'Z'
    $firstUnusedDriveLetter = [char[]] (0x41..0x5a) | 
    Where-Object { $_ -notin $takenDriveLetters } | Select-Object -first 1

    # Temporarily map the target UNC path to a drive letter...
    $null = net use ${firstUnusedDriveLetter}: $Path /persistent:no
    # ... and obtain the resulting drive's free space ...
    $freeSpace = (Get-PSDrive $firstUnusedDriveLetter).Free
    # ... and delete the mapping again.
    $null = net use ${firstUnusedDriveLetter}: /delete

    #$freeSpace # output
    If ($freeSpace) { Return $freeSpace }

    $SMBMapping = Get-SMBMapping | Where-Object {$_.LocalPath}
    $PathDrive = $Path.Substring(0, [Math]::Min($Path.Length,2) )
    If ( $PathDrive -in $SMBMapping.LocalPath ) {
        $CurrentSMB = $SMBMapping | Where-Object {$_.LocalPath -eq $PathDrive}
        $NewPath = $CurrentSMB.RemotePath + $Path.Substring(2, ($Path.Length - 2 ) )
    
        # Determine all single-letter drive names.
        $takenDriveLetters = (Get-PSDrive).Name -like '?'

        # Find the first unused drive letter.
        # Note: In PowerShell (Core) 7+ you can simplify [char[]] (0x41..0x5a) to
        #       'A'..'Z'
        $firstUnusedDriveLetter = [char[]] (0x41..0x5a) | 
        Where-Object { $_ -notin $takenDriveLetters } | Select-Object -first 1

        # Temporarily map the target UNC path to a drive letter...
        $null = net use ${firstUnusedDriveLetter}: $NewPath /persistent:no
        # ... and obtain the resulting drive's free space ...
        $freeSpace = (Get-PSDrive $firstUnusedDriveLetter).Free
        # ... and delete the mapping again.
        $null = net use ${firstUnusedDriveLetter}: /delete

        #$freeSpace # output
        If ($freeSpace) { Return $freeSpace }
    }

    Return 0
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
        $CurrentSyncPath.LocalPath = $CurrentSyncPath.LocalPath.TrimEnd("\")
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
    Return $NewDBFiles
}

#Update-SFFDataBase -Config $SFFConfig -Database $FileFolderDB -NewFile $DBFile
$ConfigCredential = Import-Clixml -Path $CredentialFile
$ConfigCredential = $ConfigCredential | Where-Object { $_.RunningUser -eq $env:USERNAME -and $_.Server -like $SFFConfig.Server }

If (!($ConfigCredential))
{
    Write-Warning "No credentials found... Aborting..."
    Return
}

$Credential = Get-PlainUsernamePassword -ConfigCredential $ConfigCredential 
$SFFConfig.TlsThumbPrint = $SFFConfig.TlsThumbPrint -replace " ","-"
$DownloadFolderNoFreeSpace = $false

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
    $Database = Update-SFFDataBase -Config $SFFConfig -Database $FileFolderDB -NewFile $DBFile
    #$Database = Get-Content -Raw -Path $DBFile -Encoding UTF8 | ConvertFrom-Json
    New-WinSCPSession -SessionOption $sessionOption
    foreach ($CurrentSyncPath in $SFFConfig.SyncPathArray)
    {
        Write-Host "Scanning FTPS-server... Current path: $($CurrentSyncPath.RemotePath)"
        $CurrentDBFiles = $Database | Where-Object {$_.DBName -like $CurrentSyncPath.DBName}
        $CurrentDBFilesList = $CurrentDBFiles | Select-Object -ExpandProperty "SyncName"
        $CurrentRemoteFiles = Get-WinSCPChildItem -Path $CurrentSyncPath.RemotePath -File -Recurse | 
            Where-Object { $_.Name -notlike "*.sl"} | 
            Select-Object -Property FileType, FullName, Mode, Name, Length, LastWriteTime, 
            @{l='SyncName';e={ $_.FullName.ToString() -replace [Regex]::Escape($CurrentSyncPath.RemotePath),"" }}, 
            @{l='DBName';e={ $CurrentSyncPath.DBName }}

        foreach ($CurrentRemoteFile in $CurrentRemoteFiles)
        {
            $CurrentRemoteReplaceName = ($CurrentRemoteFile.SyncName -replace [Regex]::Escape("/"),"\" )

            $CurrentMatch = $false
            foreach ($Skipfiles in $Blacklist)
            {
                If ($CurrentRemoteReplaceName -like $Skipfiles)
                {
                    Write-Host "Skipping file: $CurrentRemoteReplaceName - blacklist."
                    $CurrentMatch = $true
                    break
                }
            }
            If ( $CurrentMatch ) { continue }


            If ($CurrentDBFilesList -notcontains $CurrentRemoteReplaceName)
            {
                #Doublecheck for spaces in path:
                $WildCardMatchArray = $CurrentRemoteReplaceName -split "\\"
                $WildCardMatch = ($WildCardMatchArray[0], ( $WildCardMatchArray[1] -replace " ","*" ) +
                    $WildCardMatchArray[2..($WildCardMatchArray.Length)]) -join "\"
                $WildCardMatch = $WildCardMatch.replace("[","*").replace("]","*")
                $CurrentMatch = $false
                Write-Host "Potential download. Doublechecking: $CurrentRemoteReplaceName - Wildcard: $WildCardMatch."
                foreach ($CurrentDBFilesListTest in $CurrentDBFilesList)
                {
                    If ($CurrentDBFilesListTest -like $WildCardMatch)
                    {
                        $CurrentMatch = $true
                        Write-Host "Aborting - found match: $CurrentDBFilesListTest"
                        Break
                    }
                }
                If ( $CurrentMatch ) { continue }

                #Check free space before download:
                $CurrentFreeSpace = Get-FreeSpace -Path $SFFConfig.DownloadFolder
                If ($CurrentFreeSpace -lt $DownloadFolderMinimumFreeSpace) {
                    $DownloadFolderNoFreeSpace = $true
                    Write-Warning "Not enough free space in download! Aborting!"
                    break
                }

                #Time to download file!:
                $DownloadPathFile = Join-Path -Path $SFFConfig.DownloadFolder -ChildPath $CurrentRemoteFile.Name
                $NewPath = $CurrentSyncPath.LocalPath + $CurrentRemoteFile.SyncName -replace [Regex]::Escape("/"),"\"
                Write-Host "Downloading: $($CurrentRemoteFile.FullName) - $CurrentRemoteReplaceName to: $DownloadPathFile, and moving to: $NewPath"
                $Result = Receive-WinSCPItem -RemotePath $CurrentRemoteFile.FullName -LocalPath $DownloadPathFile
                If ( $Result.IsSuccess )
                {
                    $ParentFolder = Split-Path -Path $NewPath -Parent
                    If (!( Test-Path $ParentFolder -ErrorAction SilentlyContinue ))
                    {
                        mkdir $ParentFolder
                    }
                    Move-Item -Path $DownloadPathFile -Destination $NewPath
                }
            }
        }
        If ($DownloadFolderNoFreeSpace) { break }
    }
    #$Database = Update-SFFDataBase -Config $SFFConfig -Database $FileFolderDB -NewFile $DBFile
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
Write-Host "Finished script!"
