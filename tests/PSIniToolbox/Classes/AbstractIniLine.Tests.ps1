BeforeAll {
    $testsRoot = $PSScriptRoot
    while ((Split-Path $testsRoot -Leaf) -ne 'tests') { $testsRoot = Split-Path $testsRoot -Parent }
    Import-Module (Join-Path (Split-Path $testsRoot -Parent) 'src/PSIniToolbox/PSIniToolbox.psd1') -Force
}

Describe 'AbstractIniLine' {
    It 'base helpers return defaults and ToString throws' {
        $line = [AbstractIniLine]::new()
        $line.IsBlank() | Should -BeFalse
        $line.IsSection() | Should -BeFalse
        $line.IsKeyValue() | Should -BeFalse
        $line.IsCommentText() | Should -BeFalse
        { $line.ToString() } | Should -Throw
    }
}
