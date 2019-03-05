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

Function doit{
    param ([Parameter(Position=1)]
           [string]$location="c:\windows\system32",
           [Parameter(Mandatory=$false)]
           [boolean]$exeonly=$true,
           [string]$temp=$env:TEMP,
           [boolean]$beta=$true)

    write-host "Configuring download security protocols"
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    write-host "Downloading and installing the rclone binary and installing into $location"
    install-rclone $location -exeonly $exeonly
    write-host "Downloading and installing the nssm binary and installing into $location"
    install-nssm $location -exeonly $exeonly
}