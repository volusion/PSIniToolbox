BeforeAll {
    $testsRoot = $PSScriptRoot
    while ((Split-Path $testsRoot -Leaf) -ne 'tests') { $testsRoot = Split-Path $testsRoot -Parent }
    Import-Module (Join-Path (Split-Path $testsRoot -Parent) 'src/PSIniToolbox/PSIniToolbox.psd1') -Force
}

Describe 'IniLine model' {
    It 'stores parsed lines with type helpers' {
        $iniText = "; note`nappName = Demo`n`n[db]`nhost = localhost"
        $file = Join-Path $TestDrive 'lines.ini'
        Set-Content -Path $file -Value $iniText -Encoding utf8

        $doc = Get-IniContent -Path $file
        $kinds = $doc.Lines | ForEach-Object { $_.Kind }
        $kinds | Should -Be @('Comment', 'KeyValue', 'Blank', 'Section', 'KeyValue')
        ($doc.Lines | Where-Object { $_.IsSection() }).Section | Should -Be 'db'
        ($doc.Lines | Where-Object { $_.IsKeyValue() }).Count | Should -Be 2
    }

    It 'round-trips comments and blank lines unchanged' {
        $iniText = "; header`nappName = Demo`n`n[db]`nhost = localhost"
        $file = Join-Path $TestDrive 'rt-in.ini'
        $out = Join-Path $TestDrive 'rt-out.ini'
        Set-Content -Path $file -Value $iniText -Encoding utf8

        $doc = Get-IniContent -Path $file
        Save-IniContent -Document $doc -Path $out
        ((Get-Content -Raw $out) -replace "`r`n", "`n").TrimEnd() | Should -Be $iniText
    }

    It 'represents each line kind with a distinct subclass' {
        $doc = New-IniDocument
        $doc.AddComment('; c')
        $doc.Set('db', 'host', 'x')
        @($doc.Lines | Where-Object { $_ -is [IniCommentLine] }).Count | Should -Be 1
        @($doc.Lines | Where-Object { $_ -is [IniSectionLine] }).Count | Should -Be 1
        @($doc.Lines | Where-Object { $_ -is [IniKeyValueLine] }).Count | Should -Be 1
        @($doc.Lines | Where-Object { $_ -is [IniLine] }).Count | Should -Be 3
    }
}
