#Requires -Version 7.0
<#
.SYNOPSIS
    Generates PlatyPS help for PSIniToolbox: Markdown for the docs site and, optionally,
    MAML external help that ships inside the published module.

.DESCRIPTION
    Uses the modern Microsoft.PowerShell.PlatyPS module. The functions' comment-based help
    is the source of truth, so the Markdown and MAML are regenerated from the imported module
    rather than committed to the repo.

.PARAMETER OutputPath
    Folder to write the generated Markdown into. Defaults to ./docs.

.PARAMETER Maml
    Also export MAML external help (for Get-Help) into -MamlPath.

.PARAMETER MamlPath
    Folder to write the MAML help into. Defaults to the module's en-US culture folder.

.EXAMPLE
    ./Build-Docs.ps1
    Writes the Markdown pages used by the MkDocs site to ./docs.

.EXAMPLE
    ./Build-Docs.ps1 -Maml
    Also writes src/PSIniToolbox/en-US/PSIniToolbox-Help.xml for the published module.
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot 'docs'),
    [switch] $Maml,
    [string] $MamlPath = (Join-Path $PSScriptRoot 'src' 'PSIniToolbox' 'en-US')
)

$ErrorActionPreference = 'Stop'

Import-Module Microsoft.PowerShell.PlatyPS -ErrorAction Stop

$manifestPath = Join-Path $PSScriptRoot 'src' 'PSIniToolbox' 'PSIniToolbox.psd1'
$module = Import-Module $manifestPath -Force -PassThru

# PlatyPS always seeds INPUTS/OUTPUTS descriptions with a "{{ Fill in the Description }}" prompt
# and a duplicate empty entry per type. Strip the prompt text and drop the empty duplicates so the
# comment-based help is the only source that shows through.
function Clear-InputOutputPlaceholders {
    param([System.Collections.IList] $Items)
    if (-not $Items) { return }
    foreach ($item in $Items) {
        if ($item.Description) {
            $item.Description = ($item.Description -replace '(?m)^\s*\{\{.*?\}\}\s*$', '').Trim()
        }
    }
    $describedTypes = @($Items | Where-Object Description | ForEach-Object Typename)
    for ($n = $Items.Count - 1; $n -ge 0; $n--) {
        if (-not $Items[$n].Description -and $describedTypes -contains $Items[$n].Typename) {
            $Items.RemoveAt($n)
        }
    }
}

# Remaining ALIASES / RELATED LINKS / NOTES placeholders are re-emitted by Export-MarkdownCommandHelp
# for empty sections. Remove the brace prompts and any section left with an empty body.
function Remove-HelpPlaceholders {
    param([string] $Path)
    $kept = foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*\{\{.*\}\}\s*$') { continue }
        if ($line -match '^\s*This cmdlet has the following aliases,\s*$') { continue }
        $line
    }
    $kept = @($kept)

    $result = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $kept.Count; $i++) {
        if ($kept[$i] -match '^##\s+\S') {
            $j = $i + 1
            $hasBody = $false
            while ($j -lt $kept.Count -and $kept[$j] -notmatch '^##\s+\S') {
                if ($kept[$j].Trim()) { $hasBody = $true }
                $j++
            }
            if (-not $hasBody) { $i = $j - 1; continue }
        }
        $result.Add($kept[$i])
    }

    $text = (($result -join "`n") -replace '(\r?\n){3,}', "`n`n").TrimEnd() + "`n"
    Set-Content -LiteralPath $Path -Value $text -NoNewline
}

try {
    if (Test-Path -LiteralPath $OutputPath) { Remove-Item -LiteralPath $OutputPath -Recurse -Force }
    $null = New-Item -ItemType Directory -Path $OutputPath -Force

    # One Markdown page per exported command, plus a module landing page for the site index.
    $null = New-MarkdownCommandHelp -ModuleInfo $module -OutputFolder $OutputPath -WithModulePage -Force

    # Reload the command pages, strip the PlatyPS placeholders, and re-export clean Markdown.
    $commandFiles = Get-ChildItem -LiteralPath $OutputPath -Filter '*.md' -Recurse |
        Where-Object { $module.ExportedCommands.ContainsKey($_.BaseName) }
    $help = @($commandFiles | Import-MarkdownCommandHelp)
    foreach ($command in $help) {
        Clear-InputOutputPlaceholders $command.Inputs
        Clear-InputOutputPlaceholders $command.Outputs
    }
    $help | Export-MarkdownCommandHelp -OutputFolder $OutputPath -Force | Out-Null

    Get-ChildItem -LiteralPath $OutputPath -Filter '*.md' -Recurse |
        ForEach-Object { Remove-HelpPlaceholders -Path $_.FullName }

    # Use the README as the MkDocs home page.
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'README.md') -Destination (Join-Path $OutputPath 'index.md') -Force

    if ($Maml) {
        # Export-MamlCommandHelp nests output under a module-named subfolder; flatten it into en-US.
        if (Test-Path -LiteralPath $MamlPath) { Remove-Item -LiteralPath $MamlPath -Recurse -Force }
        $null = New-Item -ItemType Directory -Path $MamlPath -Force
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("platyps-maml-" + [guid]::NewGuid())
        $null = New-Item -ItemType Directory -Path $tmp -Force
        try {
            $help | Export-MamlCommandHelp -OutputFolder $tmp -Force | Out-Null
            Get-ChildItem -LiteralPath $tmp -Filter '*.xml' -Recurse | Move-Item -Destination $MamlPath -Force
        }
        finally {
            Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "Generated docs in $OutputPath" -ForegroundColor Green
    if ($Maml) { Write-Host "Generated MAML in $MamlPath" -ForegroundColor Green }
}
finally {
    Remove-Module PSIniToolbox -ErrorAction SilentlyContinue
}
