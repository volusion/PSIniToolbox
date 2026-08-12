#Requires -Version 5.1
<#
.SYNOPSIS
    Runs the PSIniToolbox Pester test suite, optionally with code coverage.
.EXAMPLE
    ./Invoke-Tests.ps1
    Runs every test under ./tests.
.EXAMPLE
    ./Invoke-Tests.ps1 -Coverage
    Runs the suite and writes a JaCoCo coverage report to ./coverage.xml.
.EXAMPLE
    ./Invoke-Tests.ps1 -Path ./tests/PSIniToolbox/Classes/IniDocument.Tests.ps1
    Runs a single test file.
.EXAMPLE
    ./Invoke-Tests.ps1 -Path ./tests/PSIniToolbox/Classes/IniDocument.Tests.ps1 -Coverage
    Runs one test file with coverage scoped to its matching source file (src/.../IniDocument.ps1).
    Whole-module coverage requires the full suite, so a single file is measured against its own source.
#>
[CmdletBinding()]
param(
    # Test file or directory to run. Defaults to the whole tests tree.
    [string]$Path = (Join-Path $PSScriptRoot 'tests'),

    # Enable code coverage over src/PSIniToolbox and write coverage.xml at the repo root.
    [switch]$Coverage,

    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$Output = 'Detailed'
)

$ErrorActionPreference = 'Stop'
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

$repoRoot = $PSScriptRoot

$config = New-PesterConfiguration
$config.Run.Path = $Path
$config.Output.Verbosity = $Output

if ($Coverage) {
    # Coverage is a whole-suite metric: measuring the whole module while running only one test
    # file reports misleadingly low numbers (other files cover the rest). So when -Path points at a
    # single test file, scope coverage to just that file's matching source file.
    $coverageTarget = Join-Path $repoRoot 'src/PSIniToolbox'
    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($item -and -not $item.PSIsContainer -and $item.Name -like '*.Tests.ps1') {
        $mapped = $item.FullName.Replace((Join-Path $repoRoot 'tests'), (Join-Path $repoRoot 'src')) -replace '\.Tests\.ps1$', '.ps1'
        if (-not (Test-Path -LiteralPath $mapped)) {
            $asModule = $mapped -replace '\.ps1$', '.psm1'  # module-level test maps to the .psm1
            if (Test-Path -LiteralPath $asModule) { $mapped = $asModule }
        }
        if (Test-Path -LiteralPath $mapped) { $coverageTarget = $mapped }
    }

    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = $coverageTarget
    $config.CodeCoverage.CoveragePercentTarget = 90
    $config.CodeCoverage.OutputFormat = 'JaCoCo'
    $config.CodeCoverage.OutputPath = Join-Path $repoRoot 'coverage.xml'
}

Invoke-Pester -Configuration $config
