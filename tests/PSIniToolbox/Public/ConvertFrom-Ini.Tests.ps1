BeforeAll {
    $testsRoot = $PSScriptRoot
    while ((Split-Path $testsRoot -Leaf) -ne 'tests') { $testsRoot = Split-Path $testsRoot -Parent }
    Import-Module (Join-Path (Split-Path $testsRoot -Parent) 'src/PSIniToolbox/PSIniToolbox.psd1') -Force
}

Describe 'ConvertFrom-Ini' {
    It 'parses a single raw multi-line string' {
        $doc = "[db]`nhost = localhost`nport = 5432" | ConvertFrom-Ini
        $doc | Should -BeOfType ([IniDocument])
        $doc.Sections['db']['host'] | Should -Be 'localhost'
        $doc.Sections['db']['port'] | Should -Be '5432'
    }

    It 'parses an array of lines' {
        $doc = @('[db]', 'host = localhost') | ConvertFrom-Ini
        $doc.Sections['db']['host'] | Should -Be 'localhost'
    }

    It 'round-trips content read with Get-Content -Raw' {
        $iniText = "[db]`nhost = localhost"
        $file = Join-Path $TestDrive 'convertfrom.ini'
        Set-Content -Path $file -Value $iniText -Encoding utf8

        $doc = Get-Content -Raw $file | ConvertFrom-Ini
        ($doc.ToString() -replace "`r`n", "`n").TrimEnd() | Should -Be $iniText
    }
}
