param([switch]$Elevated)
Add-Type -AssemblyName System.IO.Compression.FileSystem
function checkAdmin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((checkAdmin) -eq $false)  {
    if ($elevated)
    {
        # could not elevate, quit
    }
    else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
    }
    exit
}
function Unzip {
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}
 
function BackupLocalHost {
    param([string]$hostFilePath)
    Copy-Item $hostFilePath "$hostFilePath.bak_$(Get-Date -format FileDate)"
}

function UpdateHost {
    param([string]$hostFilePath, [string[]]$mvpsFileContents)
    $hostFileContents = Get-Content -Path $hostFilePath

    $count = 0;
    foreach($hostLine in $hostFileContents)
    {
        if ($hostLine -eq "# This MVPS HOSTS file is a free download from:            #") {
            break
        }
        $count++
    }

    $finalHostFileContents = $hostFileContents[0..$($count-1)] + $mvpsFileContents
    Set-Content -Path $hostFilePath -value $finalHostFileContents
    Write-Host "Done: Local Host file updated" 
}

function main() {
    $basePath = "$env:windir\system32\drivers\etc"
    $mvpsHostZipFilePath = "$basePath\mvps.zip"
    if (Test-Path("$mvpsHostZipFilePath")) { Remove-Item $mvpsHostZipFilePath -Force }
    $mvpsHostUnzipFolderPath = "$basePath\mvps"
    if (Test-Path("$mvpsHostUnzipFolderPath")) { Remove-Item $mvpsHostUnzipFolderPath -Recurse -Force }

    $mvpsHostUrl = "http://winhelp2002.mvps.org/hosts.zip"

    Write-Host "Downloading latest mvps host file from $mvpsHostUrl" 
    Invoke-WebRequest $mvpsHostUrl -OutFile $mvpsHostZipFilePath
    Unzip -zipfile $mvpsHostZipFilePath -outpath $mvpsHostUnzipFolderPath
    Remove-Item $mvpsHostZipFilePath -Force

    $mvpsFileContents = Get-Content -Path  "$mvpsHostUnzipFolderPath\hosts"
    $mvpsLicenseFileContents = Get-Content -Path  "$mvpsHostUnzipFolderPath\license.txt"
    Remove-Item $mvpsHostUnzipFolderPath -Recurse -Force

    Write-Host $($mvpsLicenseFileContents -join "`r`n" | Out-String)

    $message  = 'License'
    $question = 'MVPS Host is protected by the above license. Are you sure you want to proceed?'

    $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

    $decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
    if ($decision -eq 0) {
        BackupLocalHost -hostfilePath "$basePath\hosts"
        UpdateHost -hostFilePath "$basePath\hosts" -mvpsFileContents $mvpsFileContents
    } else {
        Write-Host 'Cancelled: Local Host file has NOT been updated'
    }
}

main
