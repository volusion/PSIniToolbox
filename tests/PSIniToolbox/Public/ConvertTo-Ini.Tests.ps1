BeforeAll {
    $testsRoot = $PSScriptRoot
    while ((Split-Path $testsRoot -Leaf) -ne 'tests') { $testsRoot = Split-Path $testsRoot -Parent }
    Import-Module (Join-Path (Split-Path $testsRoot -Parent) 'src/PSIniToolbox/PSIniToolbox.psd1') -Force
}

Describe 'ConvertTo-Ini' {
    It 'serializes an IniDocument to text' {
        $doc = New-IniDocument
        $doc.Set('db', 'host', 'localhost')
        $out = $doc | ConvertTo-Ini
        $out | Should -BeOfType ([string])
        ($out -split "`r?`n") | Should -Contain '[db]'
        ($out -split "`r?`n") | Should -Contain 'host = localhost'
    }

    It 'round-trips through ConvertFrom-Ini and ConvertTo-Ini' {
        $iniText = "[db]`nhost = localhost`nport = 5432"
        $out = $iniText | ConvertFrom-Ini | ConvertTo-Ini
        ($out -replace "`r`n", "`n").TrimEnd() | Should -Be $iniText
    }
}
