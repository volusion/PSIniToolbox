BeforeAll {
    $testsRoot = $PSScriptRoot
    while ((Split-Path $testsRoot -Leaf) -ne 'tests') { $testsRoot = Split-Path $testsRoot -Parent }
    Import-Module (Join-Path (Split-Path $testsRoot -Parent) 'src/PSIniToolbox/PSIniToolbox.psd1') -Force
}

Describe 'IniComment' {
    It 'parses the symbol and marker-free content separately' {
        $file = Join-Path $TestDrive 'comment.ini'
        Set-Content -Path $file -Value '# hello world' -Encoding utf8

        $doc = Get-IniContent -Path $file
        $comment = $doc.Lines | Where-Object { $_ -is [IniCommentLine] }
        $comment.Comment.CommentSymbol | Should -Be '#'
        $comment.Comment.Content | Should -Be 'hello world'
    }

    It 'renders a bare comment marker with no content' {
        $doc = ';' | ConvertFrom-Ini
        ($doc.ToString() -split "`r?`n") | Should -Contain ';'
    }

    It 'renders a decorative divider line without a space after the marker' {
        $doc = ';;;;;;;;;;' | ConvertFrom-Ini
        ($doc.ToString() -split "`r?`n") | Should -Contain ';;;;;;;;;;'
    }
}
