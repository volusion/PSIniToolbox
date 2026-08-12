BeforeAll {
    $testsRoot = $PSScriptRoot
    while ((Split-Path $testsRoot -Leaf) -ne 'tests') { $testsRoot = Split-Path $testsRoot -Parent }
    Import-Module (Join-Path (Split-Path $testsRoot -Parent) 'src/PSIniToolbox/PSIniToolbox.psd1') -Force
}

Describe 'IniBlankLine' {
    It 'reports IsBlank and renders as an empty string' {
        $blank = [IniBlankLine]::new((New-IniDocument), '')
        $blank.IsBlank() | Should -BeTrue
        $blank.ToString() | Should -Be ''
    }
}
