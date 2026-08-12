BeforeAll {
    $testsRoot = $PSScriptRoot
    while ((Split-Path $testsRoot -Leaf) -ne 'tests') { $testsRoot = Split-Path $testsRoot -Parent }
    Import-Module (Join-Path (Split-Path $testsRoot -Parent) 'src/PSIniToolbox/PSIniToolbox.psd1') -Force
}

Describe 'Get-IniContent' {
    BeforeAll {
        $iniText = @'
; global comment
appName = Demo

[database]
host = localhost
port = 5432
; user = admin
server = a
server = b
'@
        $tempFile = Join-Path $TestDrive 'app.ini'
        Set-Content -Path $tempFile -Value $iniText -Encoding utf8
    }

    It 'parses top-level keys' {
        $doc = Get-IniContent -Path $tempFile
        $doc.Sections['']['appName'] | Should -Be 'Demo'
    }

    It 'parses section keys' {
        $doc = Get-IniContent -Path $tempFile
        $doc.Sections['database']['host'] | Should -Be 'localhost'
        $doc.Sections['database']['port'] | Should -Be '5432'
    }

    It 'collects repeated keys into an array' {
        $doc = Get-IniContent -Path $tempFile
        $doc.Sections['database']['server'] | Should -Be @('a', 'b')
    }

    It 'accepts pipeline input' {
        $doc = Get-Item $tempFile | Get-IniContent
        $doc | Should -BeOfType ([IniDocument])
    }

    It 'records the source path on the document' {
        (Get-IniContent -Path $tempFile).Path | Should -Not -BeNullOrEmpty
    }
}
