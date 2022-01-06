<#
  Script:  Install-CMSoftwareUpdatePoint.ps1
  Date:    21-Feb-2020
  Author:  Mark Goodman
  Version: 1.0
  
  This script is provided "AS IS" with no warranties, confers no rights and 
  is not supported by the authors.
#>

<#
    .SYNOPSIS
    Installs the ConfigMgr Software Update point role

    .DESCRIPTION
    <Long description>

    .PARAMETER ParamName
    <parameter description>
	
    .EXAMPLE
    <ScriptName>.ps1
	
	Description
	-----------
	<example description>
#>

#-- Parameters --#
[cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
param(
  [Parameter(Mandatory=$true,HelpMessage="",Position=0)]
  [ValidateNotNullOrEmpty()]
  [String]$SiteServer,

  [Parameter(Mandatory=$true,HelpMessage="",Position=1)]
  [ValidateNotNullOrEmpty()]
  [String]$WsusContentPath,

  [Parameter(Mandatory=$true,HelpMessage="",Position=2)]
  [ValidateNotNullOrEmpty()]
  [String]$SqlServer,

  [Parameter(Mandatory=$false,HelpMessage="")]
  [ValidateNotNullOrEmpty()]
  [String]$SqlInstance
)

#-- Script Environment --#
#Requires -Version 4
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest

#-- Functions --#
function Do-Something {
  <#
  .SYNOPSIS
  Describe the function here
  .DESCRIPTION
  Describe the function in more detail
  .EXAMPLE
  Give an example of how to use it
  .EXAMPLE
  Give another example of how to use it
  .PARAMETER computername
  The computer name to query. Just one.
  .PARAMETER logname
  The name of a file to write failed computer names to. Defaults to errors.txt.
  #>

  [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
  param
  (
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="")]
      [ValidateNotNullOrEmpty()]
      [String[]]$Name
  )

  begin
  {
    #-- Begin code only runs once --#
  }

  process
  {
    #-- Process block --#
    write-verbose "Beginning process loop"

    foreach ($Item in $Name) {
      Write-Verbose "Processing $Item"

      # Following if statement handles the -WhatIf and -Confirm switches
      if ($PSCmdlet.ShouldProcess($Item)) {
        # use $Item here
      }
    }
  }
}

#-- Script variables --#
# PS v2+ = $scriptDir = split-path -path $MyInvocation.MyCommand.Path -parent
# PS v4+ = User $PSScriptRoot for script path
$WsusFeatures = @(
  # NetFx features
  "NET-Framework-Core", 
  "NET-Framework-45-Core",

  # IIS features
  "Web-Default-Doc",
  "Web-Dir-Browsing",
  "Web-Http-Errors",
  "Web-Static-Content",
  "Web-Http-Logging",
  "Web-Stat-Compression",
  "Web-Dyn-Compression",
  "Web-Filtering",
  "Web-Windows-Auth",
  "Web-Net-Ext45",
  "Web-Asp-Net45",
  "Web-ISAPI-Ext",
  "Web-ISAPI-Filter",
  "Web-Mgmt-Console",
  "Web-Metabase",

  # WSUS features
  "UpdateServices-Services",
  "UpdateServices-DB",
  "UpdateServices-RSAT",
  "UpdateServices-API",
  "UpdateServices-UI", 
  "NET-Framework-45-ASPNET",
  "NET-WCF-HTTP-Activation45",
  "WAS-Config-APIs",
  "WAS-Process-Model"
)

#-- Main code block --#
# Install WSUS Administration console on site server if remote
$ComputerInfo = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_ComputerSystem
if ($SiteServer -ne $ComputerInfo.Name -and $SiteServer -ne "$($ComputerInfo.Name).$($ComputerInfo.Domain)") {
  Install-WindowsFeature -ComputerName $SiteServer -Name "UpdateServices-RSAT" -IncludeAllSubFeature
}

# Create WSUS content path if it does not exist
if (!(Test-Path -Path $WsusContentPath)) {
  Write-Output -InputObject "INFO: Specified WSUS content folder was not found`n"
  try {
    Write-Output -InputObject "INFO: Creating $($WsusContentPath)`n"
    New-Item $WsusContentPath -ItemType Directory -Force | Out-Null
    Write-Output -InputObject "INFO: WSUS content path created successfully`n"
  }
  catch {
    Write-Output -InputObject "ERROR: Failed to create WSUS content path $($WsusContentPath)`n"
    Exit 3 # path not found
  }
}

# Install server roles and features
$FeatureList = ""
foreach ($Feature in $WsusFeatures) {
  $FeatureList += $Feature + ","
}
$FeatureList = $FeatureList.substring(0,$FeatureList.length -1)
Write-Output -InputObject "INFO: Installing following roles and features`nINFO: $($FeatureList)`n"
Install-WindowsFeature -Name $FeatureList

# Configure WSUS
$WsusUtil = "$($env:ProgramFiles)\Update Services\Tools\WsusUtil.exe"
if ($SqlInstance) {
  $WsusUtilArgs = "POSTINSTALL SQL_INSTANCE_NAME=$($SqlServer)\$($SqlInstance) CONTENT_DIR=$($WsusContentPath)"
}
else {
  $WsusUtilArgs = "POSTINSTALL SQL_INSTANCE_NAME=$($SqlServer) CONTENT_DIR=$($WsusContentPath)"
}

Write-Output "INFO: Starting the WSUS postinstall configuration`n"
Start-Process -FilePath $WsusUtil -ArgumentList $WsusUtilArgs -NoNewWindow -Wait
Write-Output "INFO: Successfully installed and configured WSUS"
