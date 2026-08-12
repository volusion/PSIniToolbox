BeforeAll {
    $testsRoot = $PSScriptRoot
    while ((Split-Path $testsRoot -Leaf) -ne 'tests') { $testsRoot = Split-Path $testsRoot -Parent }
    Import-Module (Join-Path (Split-Path $testsRoot -Parent) 'src/PSIniToolbox/PSIniToolbox.psd1') -Force
}

Describe 'Save-IniContent' {
    It 'writes a document to the given -Path' {
        $doc = New-IniDocument
        $doc.Set('app', 'name', 'Demo')
        $out = Join-Path $TestDrive 'explicit.ini'

        Save-IniContent -Document $doc -Path $out

        (Get-IniContent -Path $out).Sections['app']['name'] | Should -Be 'Demo'
    }

    It 'without -Path uses the document path' {
        $file = Join-Path $TestDrive 'save-path.ini'
        Set-Content -Path $file -Value "[db]`nhost = localhost" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.Set('db', 'port', '5432')
        $doc | Save-IniContent

        (Get-IniContent -Path $file).Sections['db']['port'] | Should -Be '5432'
    }

    It 'throws when neither -Path nor a document path is available' {
        { New-IniDocument | Save-IniContent } | Should -Throw
    }

    It 'round-trips values written and read back' {
        $doc = New-IniDocument
        $doc.Set('app', 'name', 'Demo')
        $out = Join-Path $TestDrive 'roundtrip.ini'

        Save-IniContent -Document $doc -Path $out
        $reloaded = Get-IniContent -Path $out

        $reloaded.Sections['app']['name'] | Should -Be 'Demo'
    }
}
