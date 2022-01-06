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
    Installs the ConfigMgr Software Update point role including prerequisites

    .DESCRIPTION
    Runs from the site server to install the Software Update point role on the site server or remote server.

    .PARAMETER WsusContentPath
    Specifies the path for WSUS content.

    .PARAMETER SqlServer
    Specifies the SQL Server computer name to install the WSUS database on.

    .PARAMETER SqlInstance
    Specifies the SQL Server instance to install the WSUS database on. Do not specify to use the Default instance.

    .PARAMETER ComputerName
    Specifies the server to install the Software Update point on. If not specified, the role is installed 
    on the local server.
	
    .EXAMPLE
    Install-CMSoftwareUpdatePoint.ps1
	
	Description
	-----------
	<example description>
#>

#-- Parameters --#
[cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
param(
  [Parameter(Mandatory=$true,Position=1)]
  [ValidateNotNullOrEmpty()]
  [String]$WsusContentPath,

  [Parameter(Mandatory=$true,Position=2)]
  [ValidateNotNullOrEmpty()]
  [String]$SqlServer,

  [Parameter(Mandatory=$false)]
  [ValidateNotNullOrEmpty()]
  [String]$SqlInstance,

  [Parameter(Mandatory=$false)]
  [ValidateNotNullOrEmpty()]
  [String]$ComputerName
)

#-- Script Environment --#
#Requires -Version 4
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest

#-- Functions --#

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
# Install WSUS Administration console on site server if SUP will be remote
$ComputerInfo = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_ComputerSystem
if ($PSBoundParameters.Contains("ComputerName")) {
  Install-WindowsFeature -Name "UpdateServices-RSAT" -IncludeAllSubFeature
}

# Create WSUS content path if it does not exist
$CreateWsusFolder = {
  New-Item $Using:WsusContentPath -ItemType Directory -Force | Out-Null
  Test-Path -Path $Using:WsusContentPath
}
Write-Output -InputObject "INFO: Creating $($WsusContentPath)`n"
$Result = Invoke-Command -ComputerName $ComputerName -ScriptBlock $CreateWsusFolder
if ($Result) {
  Write-Output -InputObject "INFO: WSUS content path created successfully`n"
}
else {
  Write-Output -InputObject "ERROR: Failed to create WSUS content path $($WsusContentPath)`n"
  Exit 3 # path not found
}

# Install server roles and features
$FeatureList = ""
foreach ($Feature in $WsusFeatures) {
  $FeatureList += $Feature + ","
}
$FeatureList = $FeatureList.substring(0,$FeatureList.length -1)
Write-Output -InputObject "INFO: Installing following roles and features`nINFO: $($FeatureList)`n"
Install-WindowsFeature -ComputerName $ComputerName -Name $FeatureList

# Configure WSUS
$WsusUtil = "$($env:ProgramFiles)\Update Services\Tools\WsusUtil.exe"
if ($SqlInstance) {
  $WsusUtilArgs = "POSTINSTALL SQL_INSTANCE_NAME=$($SqlServer)\$($SqlInstance) CONTENT_DIR=$($WsusContentPath)"
}
else {
  $WsusUtilArgs = "POSTINSTALL SQL_INSTANCE_NAME=$($SqlServer) CONTENT_DIR=$($WsusContentPath)"
}

Write-Output "INFO: Starting the WSUS postinstall configuration`n"
Invoke-Command -ComputerName $ComputerName -FilePath $WsusUtil -ArgumentList $WsusUtilArgs
# Doses the above wiat or do we need to do a script block to make it wait
Start-Process -FilePath $WsusUtil -ArgumentList $WsusUtilArgs -NoNewWindow -Wait
Write-Output "INFO: Successfully installed and configured WSUS"
