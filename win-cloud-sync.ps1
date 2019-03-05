#requires -version 3
<#
.SYNOPSIS
  Installs the win-cloud-sync service to synchronize a local path with the cloud.

.DESCRIPTION
  This script will install a service called win-cloud-sync on your system."

  There are two required components for this setup, namely rcloud and
  nssm.

  Rcloud is an utility that does the actual synchronizaiton of files
  and directories, while nssm (The Non-Sucking Service Manager) installs,
  configures, and runs rcloud at regular intervals.

  win-cloud-sync is given a base directory and will by default do
  the following:

  $base\programs\rclone.exe         - the rclone binary
  $base\programs\nssm.exe           - the nssm binary
  $base\programs\win-cloud-sync.ps1 - this script
  $base\data                        - data to synchronize

.PARAMETER BasePath
  The local path to install to and sync.

.PARAMETER BasePath
  The local path to install to and sync.

.INPUTS
  -LocalPath to install.
  -exeonly If you only want to deal with the exe.
  -Temp Location to use for temp.
  -beta To download the latest beta

.OUTPUTS
  Outputs rclone version for verification

.NOTES
  Author:Alexander Kjeldaas

.EXAMPLE

  win-cloud-sync -location "d:\directory"
  install-rclone -location "c:\rclone" -execonly $true -temp "c:\mytemp" -beta $true
#>

# This 
# param ($ComputerName = $(throw "ComputerName parameter is required."))
param (
    [string]$server = "http://defaultserver",
#    [string]$password = $(Read-Host "Input password, please"),
    [switch]$force = $false
)

#[remote]
#type = google cloud storage
#client_id =
#client_secret =
#token = {"AccessToken":"xxxx.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx","RefreshToken":"x/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx_xxxxxxxxx","Expiry":"2014-07-17T20:49:14.929208288+01:00","Extra":null}
#project_number = 12345678
#object_acl = private
#bucket_acl = private

# write-host "This script will install a service called win-cloud-sync on your system."
# write-host "The win-cloud-sync This script will install a service called win-cloud-sync on your system"

$scriptUrl = "https://raw.githubusercontent.com/alexanderkjeldaas/win-cloud-sync/master/lib.ps1"
write-host "Fetching and executing $scriptUrl"
$content = (Invoke-WebRequest -Uri $scriptUrl -Headers @{"Cache-Control"="no-cache"}).content
Invoke-Expression $content
DoIt .