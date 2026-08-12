BeforeAll {
    $testsRoot = $PSScriptRoot
    while ((Split-Path $testsRoot -Leaf) -ne 'tests') { $testsRoot = Split-Path $testsRoot -Parent }
    Import-Module (Join-Path (Split-Path $testsRoot -Parent) 'src/PSIniToolbox/PSIniToolbox.psd1') -Force
}

Describe 'IniKeyValueLine' {
    It 'renders using its parent document formatting' {
        $doc = New-IniDocument
        $doc.Set('db', 'host', 'localhost')
        $kv = $doc.Lines | Where-Object { $_ -is [IniKeyValueLine] }
        $kv.ToString() | Should -Be 'host = localhost'
        $doc.DelimiterSpacing = [IniDelimiterSpacing]::None
        $kv.ToString() | Should -Be 'host=localhost'
    }

    It 'renders a disabled line commented out' {
        $doc = 'host = localhost' | ConvertFrom-Ini
        $kv = $doc.Lines | Where-Object { $_ -is [IniKeyValueLine] } | Select-Object -First 1
        $kv.IsDisabled = $true
        $kv.ToString() | Should -Be '; host = localhost'
    }
}
