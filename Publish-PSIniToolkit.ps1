<#
.SYNOPSIS
    Validates and publishes the PSIniToolbox module to the PowerShell Gallery.

.DESCRIPTION
    Runs a manifest test, then publishes the module. Supply your PowerShell Gallery
    API key via the -ApiKey parameter or the PSGALLERY_API_KEY environment variable.
    Use -WhatIf to preview without publishing.

.PARAMETER ApiKey
    PowerShell Gallery API key. Defaults to the PSGALLERY_API_KEY environment variable.

.PARAMETER Repository
    Target repository name. Defaults to 'PSGallery'.

.EXAMPLE
    ./Publish-PSIniToolkit.ps1 -WhatIf

.EXAMPLE
    ./Publish-PSIniToolkit.ps1 -ApiKey $env:PSGALLERY_API_KEY
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [string] $ApiKey = $env:PSGALLERY_API_KEY,
    [string] $Repository = 'PSGallery'
)

$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'src' 'PSIniToolbox'
$manifestPath = Join-Path $modulePath 'PSIniToolbox.psd1'

Write-Host "Testing manifest: $manifestPath" -ForegroundColor Cyan
$manifest = Test-ModuleManifest -Path $manifestPath
Write-Host "  $($manifest.Name) v$($manifest.Version)" -ForegroundColor Green

Write-Host "Importing module to verify it loads..." -ForegroundColor Cyan
Import-Module $manifestPath -Force -ErrorAction Stop
Remove-Module 'PSIniToolbox' -ErrorAction SilentlyContinue

if (-not $ApiKey) {
    throw "No API key provided. Pass -ApiKey or set the PSGALLERY_API_KEY environment variable."
}

if ($PSCmdlet.ShouldProcess("$($manifest.Name) v$($manifest.Version)", "Publish to $Repository")) {
    Publish-Module -Path $modulePath -NuGetApiKey $ApiKey -Repository $Repository -Verbose
    Write-Host "Published $($manifest.Name) v$($manifest.Version) to $Repository." -ForegroundColor Green
}
