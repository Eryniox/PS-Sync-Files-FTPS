#Requires -Version 5

[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSProvideDefaultParameterValue", "Version")]
$Version = 0.01

$ConfigFile = $PSScriptRoot + "\config.clixml"

$AllSyncFolders = @{
    Server = "ftps.notaserver.example.com"
    Port = 21
    TlsThumbPrint = "11-22-33-44-55-66-77-88-99-00-aa-bb-cc-dd-ee-ff-gg-hh-ii-jj"
    DBArchive = "C:\Scripts\DBBackup"
    ScriptBackup = "C:\Scripts\symlik\Backup"
    DownloadFolder = "C:\symlink\Download"
    DBFileName = "SFF-DB.json"
    SyncPathArray = @(
        @{  
            DBName = "Sync1"
            LocalPath = "C:\syncPath1" 
            RemotePath = "/somepath1"
        }, 
        @{  
            DBName = "Sync4"
            LocalPath = "C:\syncPath4" 
            RemotePath = "/somepath44"
        }, 
        @{  
            DBName = "Sync666"
            LocalPath = "C:\syncPath666" 
            RemotePath = "/somepath666"
        }, 
        @{  
            DBName = "Sync7"
            LocalPath = "C:\syncPath7" 
            RemotePath = "/7somepath"
        }
    )
}

If (Test-Path -Path $ConfigFile)
{
    Remove-Item -Path $ConfigFile
}

$AllSyncFolders | Export-Clixml -Path $ConfigFile
