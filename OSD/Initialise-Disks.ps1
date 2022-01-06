<#
  Script:  Initialise-Disks.ps1
  Date:    07-Jul-2018
  Author:  Mark Goodman
  Version: 1.0
  
  This script is provided "AS IS" with no warranties, confers no rights and 
  is not supported by the authors.
#>

<#
    .SYNOPSIS
    Creates and formats new data partitions for offline disks

    .DESCRIPTION
    For use with OSD. Initilaise any offline disk, creates a new data GPT data partition and formats as NTFS.
	
    .EXAMPLE
    Initilise-Disks.ps1
#>

#-- Parameters --#
[cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
param(
  [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][ValidateLength(1,1)][ValidatePattern('[A-Z]')][String]$StartingDriveLetter = "D",
  [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][String]$LogFile = "Initialise-Disks.log"
)

#-- Script Environment --#
#Requires -Version 4
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest

#-- Functions --#

<#  Script variables  #>
# PS v2+ = $scriptDir = split-path -path $MyInvocation.MyCommand.Path -parent
# PS v4+ = User $PSScriptRoot for script path
$DriveLetterCode = [int][char]$StartingDriveLetter

#-- Main code block --#
if ($LogFile -eq "Initialise-Disks.log")
{
  try
  {
    # Get TS environment
    $tsEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction Stop
    if ($tsEnv.Value("_SMSTSLogPath") -ne $null)
    {
      $LogFile = "$($tsEnv.Value('_SMSTSLogPath'))\$($LogFile)"
    }
    elseif ($tsEnv.Value("LogPath") -ne $null)
    {
      $LogFile = "$($tsEnv.Value('LogPath'))\$($LogFile)"
    }
    else
    {
      $LogFile = "$($env:TEMP)\$($LogFile)"
    }
    Remove-Variable tsEnv -Force
  }
  catch
  {
    # Not running in TS
    $LogFile = "$($env:TEMP)\$($LogFile)"
  }
}

# Start logging
Start-Transcript -Path $LogFile

# Get offline disks
$DataDisks = Get-Disk | Where-Object -Property OperationalStatus -EQ -Value "Offline"
$DataDisks
foreach ($Disk in $DataDisks)
{
  # Initialise disk and create partition
  Write-Information -MessageData "Initalising disk $($Disk.Number) as drive $([char]$DriveLetterCode)"
  Initialize-Disk -Number $Disk.Number -PartitionStyle GPT -PassThru
  New-Partition -DiskNumber $Disk.Number -UseMaximumSize -DriveLetter $([char]$DriveLetterCode)
  Format-Volume -DriveLetter $([char]$DriveLetterCode) -FileSystem NTFS -NewFileSystemLabel "Data" -Force
  $DriveLetterCode++
}

# Stop logging
Stop-Transcript
