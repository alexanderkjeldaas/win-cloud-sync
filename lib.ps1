#requires -version 3

Add-Type -AssemblyName System.IO.Compression.FileSystem

Function Unzip{
    param([string]$zipfile, [string]$outpath)
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

Function Test-write{
    param (
        [Parameter(Mandatory=$True,Position=1)]
        [string]$path)
    $random = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 25 | % {[char]$_})
    try{
        "TESTWRITE" | Out-File -FilePath $path\$random -ErrorAction SilentlyContinue
    } catch { }
    $wrote = (Test-Path $path\$random -ErrorAction SilentlyContinue)
    if ($wrote) {
        Remove-Item $path\$random -ErrorAction SilentlyContinue;
        return $true
    } else {
        return $false
    }
}

Function Test-write-multiple{
    param([string]$location, [string]$temp)
    if (!(Test-write $location)){
        write-warning "Unable to write to location.";
        return $false
    }
    if (!(Test-write $temp)){
        write-warning "Unable to write to temp location.";
        return $false
    }
    return $true
}

# From https://gist.githubusercontent.com/justusiv/1ff2ad273cea3e33ca4acc5cab24c8e0/raw
# but rewritten
Function Install-Rclone{
    param ([Parameter(Position=1)]
           [string]$location="c:\windows\system32",
           [Parameter(Mandatory=$false)]
           [boolean]$exeonly=$true,
           [string]$temp=$env:TEMP,
           [boolean]$beta=$true)

    if (!(Test-write-multiple $location $temp)){
        return
    }

    $url = switch ( $beta ) {
        $true  { "http://beta.rclone.org/rclone-beta-latest-windows-amd64.zip" }
        $false { "http://downloads.rclone.org/rclone-current-windows-amd64.zip" }
    }

    $zipFile, $rcloneWindows = @("rclone-windows.zip", "rclone-windows") |
        foreach {Join-Path -Path $temp -ChildPath $_}
    Invoke-WebRequest -Uri $url -OutFile $zipFile

    Unzip $zipFile $rcloneWindows

    $allItems = (dir (dir $rcloneWindows).FullName)

    $items = switch ($exeonly) {
        $true  { $allItems | Where-Object {($_.name -eq "rclone.exe") -or ($_.name -eq "rclone")}}
        $false { $allItems }
    }

    foreach ($item in $items) {
        Move-Item $item.FullName -Destination $location -Force
    }

    @($rcloneWindows, $zipFile) | foreach {Remove-Item $_ -Recurse}

    $rclone,$rcloneExe = @("rclone", "rclone.exe") | foreach {Join-Path -Path $location -ChildPath $_}
    Move-Item $rclone $rcloneExe -Force -ErrorAction SilentlyContinue

#    & $location\rclone.exe --version -q
}


Function install-nssm{
    param ([Parameter(Position=1)]
           [string]$location="c:\windows\system32",
           [Parameter(Mandatory=$false)]
           [boolean]$exeonly=$true,
           [string]$temp=$env:TEMP,
           [boolean]$beta=$true)

    if (!(Test-write-multiple $location $temp)){
        return
    }

    $url = "https://nssm.cc/ci/nssm-2.24-101-g897c7ad.zip"

    $zipFile, $nssmWindows = @("nssm-windows.zip", "nssm-windows") |
        foreach {Join-Path -Path $temp -ChildPath $_}
    @($nssmWindows, $zipFile) | foreach {Remove-Item $_ -Recurse -Force -ErrorAction Ignore} 
    Invoke-WebRequest -Uri $url -OutFile $zipFile

    Unzip $zipFile $nssmWindows
    write-host "Uncompressed nssm distribution from $zipFile into $nssmWindows"

    $item = Join-Path -Path (dir (dir $nssmWindows).FullName | where {$_.name -eq "win64"}).FullName -ChildPath "nssm.exe"

    Move-Item $item -Destination $location -Force

    # Hack to remove a nasty .gitignore file that is wrongly assumed to give
    # a permission denied issue.
    # TODO: Better detection of OS X
    if ($env:OS -ne "Windows_NT") {
        remove-item -Force (dir -Hidden (dir (dir $nssmWindows)))
    }

    # Do a regular remove
    @($nssmWindows, $zipFile) | foreach {Remove-Item $_ -Recurse}
}

Function Write-RClone-Conf{
    param (
           [string]$location,
           [string]$serviceAccountFile
    )

    $outfile = Join-Path $location "rclone.conf"
    Remove-Item $outfile -ErrorAction Ignore
    @("[astorai]",
      "type = gcs",
      "service_account_file = $serviceAccountFile",
      "object_acl = bucketOwnerFullControl",
      "location = europe-north1"
    ) | foreach {add-content $outfile -Value $_}
}


function install-nssm-service{
    param (
           [string]$location,
           [string]$emiInputFolder,
           [string]$emiOutputFolder,
           [string]$logs,
           [string]$clientName
    )
    $nssm = Join-Path $location "nssm.exe"
    foreach ($item in @("astorai-input", "astorai-output")) {
        if (Get-Service $item -ErrorAction Ignore) {
            & $nssm stop $item
            & $nssm remove $item confirm
        }
    }
    $configLocation = Join-Path $location "rclone.conf"
    $rcloneBinary = Join-Path $location "rclone"
    & $nssm install astorai-input $rcloneBinary "-v --config $configLocation sync astorai:waybills/$clientName/toEMI $emiInputFolder"
    & $nssm install astorai-output $rcloneBinary "-v --config $configLocation sync $emiOutputFolder astorai:waybills/$clientName/fromEMI"
    foreach ($item in @("astorai-input", "astorai-output")) {
        & $nssm set $item Description "EMI sync between local and remote folders"
        & $nssm set $item AppDirectory $location
        & $nssm set $item AppRestartDelay 300000
        & $nssm set $item AppStdout (Join-Path $logs "$item.log")
        & $nssm set $item AppStderr (Join-Path $logs "$item.err")
        & $nssm set $item AppExit Default Restart
        & $nssm set $item AppRotateFiles 1
        & $nssm set $item AppRotateOnline 0
        # 1 week log rotation
        & $nssm set $item AppRotateSeconds 604800
        & $nssm set $item AppRotateBytes 10000000
        & $nssm start $item
    }
}

Function doit{
    param (
           [string]$location="c:\windows\system32",
           [Parameter(Mandatory=$true)]
           [string]$serviceAccountFile,
           [Parameter(Mandatory=$true)]
           [string]$emiInputFolder,
           [Parameter(Mandatory=$true)]
           [string]$emiOutputFolder,
           [Parameter(Mandatory=$true)]
           [string]$clientName,
           [Parameter(Mandatory=$false)]
           [boolean]$exeonly=$true,
           [string]$temp=$env:TEMP,
           [boolean]$beta=$true)

    $logs = Join-Path $location "logs"
    foreach ($item in @($location, $emiInputFolder, $emiOutputFolder, $logs)) {
        write-host "Checking that $item exist and is writable";
        if (!(Test-write $item)) {
            write-host "$item was not writable.  I will try to create it and retry";
            New-Item -ItemType Directory -Force -Path $item | out-null
            if (!(Test-write $item)) {
                write-host "$item is still not writable.";
                throw "Giving up"
            }
        }
    }
    $emiInputFolderResolved = Resolve-Path $emiInputFolder
    $emiOutputFolderResolved = Resolve-Path $emiOutputFolder
    $serviceAccountFileDest = Join-Path $location "service_account_file.txt"
    write-host "Configuring download security protocols"
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    write-host "Downloading and installing the rclone binary and installing into $location"
    install-rclone $location -exeonly $exeonly
    write-host "Downloading and installing the nssm binary and installing into $location"
    install-nssm $location -exeonly $exeonly
    write-host "Copying the service account file from $serviceAccountFile to $serviceAccountFileDest"
    Copy-Item $serviceAccountFile -Destination $serviceAccountFileDest -Force
    write-host "Creating rclone config for the 'astorai' remote"
    write-rclone-conf $location $serviceAccountFileDest
    if ($env:OS -eq "Windows_NT") {
        write-host "Setting up an nssm service that syncs"
        write-host $emiInputFolderResolved
        write-host $emiOutputFolderResolved
        write-host "every 5 minutes"
        install-nssm-service $location $emiInputFolderResolved $emiOutputFolderResolved $logs $clientName
    }
}