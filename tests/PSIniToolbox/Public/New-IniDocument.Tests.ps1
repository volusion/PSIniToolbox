BeforeAll {
    $testsRoot = $PSScriptRoot
    while ((Split-Path $testsRoot -Leaf) -ne 'tests') { $testsRoot = Split-Path $testsRoot -Parent }
    Import-Module (Join-Path (Split-Path $testsRoot -Parent) 'src/PSIniToolbox/PSIniToolbox.psd1') -Force
}

Describe 'New-IniDocument' {
    It 'creates an empty IniDocument' {
        $doc = New-IniDocument
        $doc | Should -BeOfType ([IniDocument])
        $doc.Lines.Count | Should -Be 0
        $doc.Sections.Count | Should -Be 1  # only the empty-string top-level section
        $doc.ToString().Trim() | Should -Be ''
    }
}
