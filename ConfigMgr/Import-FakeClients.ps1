<#
  Script:  Import-FakeClients
  Date:    07-Oct-2020
  Author:  Mark Goodman
  Version: 1.0
  
  This script is provided "AS IS" with no warranties, confers no rights and 
  is not supported by the authors.
#>

<#
    .SYNOPSIS
    Imports fake client devices in to Configuration Manager

    .DESCRIPTION
    Imports fake client devices in to Configuration Manager for testing. 
    Generates a CSV import file containing a list of device names and MAC addresses.
    You can specify the prefix for the device name and whether to use a number of set of random characters for the remainder.
    MAC address is randomly generated but you can specify the first 2 characters
    The list of devices is exported to a temporary CSV file and then imported using the Import-CMComputerInformation cmdlet.

    .PARAMETER Total
    Specify the total number of fake clients to create

    .PARAMETER Prefix
    Specify the device name prefix to use.

    .PARAMETER CollectionName
    The name of the collection to add the clients to. This will be created if it does not exist.
    
    .PARAMETER Digits
    Specify to use random digits for 
	
    .EXAMPLE
    <ScriptName>.ps1
	
	Description
	-----------
	<example description>
#>

#TODO: Add support for random characters (bit like serial number) for computer name
#TODO: Add support for specifing first 2 characters of MAC address
#
#-- Parameters --#
[cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [Int32]$Total,

  [Parameter(Mandatory=$true,Position=1)]
  [ValidateNotNullOrEmpty()]
  [ValidatePattern("^[A-Za-z\d]*[A-Za-z]+[A-Za-z\d]*")]
  [String]$Prefix,

  [Parameter(Mandatory=$true)]
  [String]$CollectionName
)

#-- Script Environment --#
#Requires -Version 4
# #Requires -RunAsAdministrator
Set-StrictMode -Version Latest

#-- Functions --#
function Import-CMModule {
  #-- Parameters --#
  [cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
  param()

  # Check if ConfigMgr PS module is installed already
  if ($null -eq (Get-Module -Name ConfigurationManager)) {
    # Get SMS Provider info and import module
    Write-Verbose -Message "Import ConfigMgr PowerShell module"
    $Path = "$($env:SMS_ADMIN_UI_PATH)..\..\ConfigurationManager.psd1"
    if (Test-Path -Path $Path) {
      # Import module
      Import-Module -Name $Path
    }
    else {
      # Cannot find module
      write-warning -Message "Failed to find ConfigMgr module!"
    }
  }

  # Check if ConfigMgr PS drive is connected already
  $SMSProvider = Get-CimInstance -Namespace root\sms -ClassName SMS_ProviderLocation
  $CMDrive = Get-PSDrive -Name $SMSProvider.SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue
  if ($null -eq $CMDrive) {
    # Connect site drive
    Write-Verbose -Message "Connect CMSite PSDrive"
    $CMDrive = New-PSDrive -Name $SMSProvider.SiteCode -PSProvider CMSite -Root $SMSProvider.Machine 
  }
  Set-Location -Path "$($CMDrive.Name):"
}

#-- Script variables --#
# PS v2+ = $scriptDir = split-path -path $MyInvocation.MyCommand.Path -parent
# PS v4+ = Use $PSScriptRoot for script path

#-- Main code block --#
try {
  # Import ConfigMgr PS module
  Import-CMModule
}
catch {
  # Failed to import CM PS module
  Write-Warning -Message "Failed to load ConfigMgr PowerShell module"
  Write-Warning -Message "Error $($Error[0].Exception.HResult)"
  Exit $Error[0].Exception.HResult
}

# Create collection if it does not exist
if ($null -eq (Get-CMDeviceCollection -Name $CollectionName)) {
  New-CMDeviceCollection -Name $CollectionName -LimitingCollectionName "All Systems" | Out-Null
}

# Create temporary file
$ImportFile = New-TemporaryFile

# Update file with fake client details
"Name,MAC Address,SMBIOS GUID" | Out-File -FilePath $ImportFile.FullName
1..$Total | ForEach-Object {
  $MacAddress = [BitConverter]::ToString([BitConverter]::GetBytes((Get-Random -Maximum 0xFFFFFFFFFFFF)), 0, 6).Replace('-', ':')
  "{0}{1:000000},{2}" -f $Prefix, $_, $macaddress | Out-File -FilePath $ImportFile.FullName -Append
}

# Import fake clients
Import-CMComputerInformation -CollectionName $CollectionName -EnableColumnHeading $true -FileName $ImportFile
