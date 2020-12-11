#Requires -Version 5

[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSProvideDefaultParameterValue", "Version")]
$Version = 0.01

$ConfigFile = $PSScriptRoot + "\config.clixml"

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
    $FileFolderDB = Get-Content -Raw -Path $DBFile | ConvertFrom-Json
    #Import-Clixml -Path $DBFile
} Else {
    $FileFolderDB = @()
}

$NewDBFiles = @()
foreach ($CurrentSyncPath in $SFFConfig.SyncPathArray)
{
    $CurrentDBFiles = $FileFolderDB | Where-Object {$_.DBName -like $CurrentSyncPath.DBName} # | Select-Object -ExpandProperty SyncName
    $CurrentLocalFiles = Get-ChildItem $SFFConfig.LocalPath -Recurse -Force -File | 
        Select-Object -Property BaseName, Mode, Name, Length, DirectoryName, Directory, 
        FullName, Extension, CreationTime, LastWriteTime, 
        @{l='SyncName';e={ $_.FullName.ToString() -replace [Regex]::Escape($CurrentSyncPath.LocalPath),"" }}, 
        @{l='DBName';e={ $CurrentSyncPath.DBName }}

    $TotalCurrentFiles = $CurrentDBFiles + $CurrentLocalFiles | Sort-Object -Property SyncName -Unique
    $NewDBFiles += $TotalCurrentFiles
}

$NewDBFiles | ConvertTo-Json  | Set-Content -Path $DBFile -Force 
