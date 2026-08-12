BeforeAll {
    $testsRoot = $PSScriptRoot
    while ((Split-Path $testsRoot -Leaf) -ne 'tests') { $testsRoot = Split-Path $testsRoot -Parent }
    Import-Module (Join-Path (Split-Path $testsRoot -Parent) 'src/PSIniToolbox/PSIniToolbox.psd1') -Force
}

Describe 'AbstractIniDocument' {
    It 'IniDocument derives from AbstractIniDocument' {
        New-IniDocument | Should -BeOfType ([AbstractIniDocument])
    }

    It 'abstract methods throw until overridden' {
        $a = [AbstractIniDocument]::new()
        { $a.Get('k') } | Should -Throw
        { $a.Get('s', 'k') } | Should -Throw
        { $a.Add('k', 'v') } | Should -Throw
        { $a.Add('s', 'k', 'v') } | Should -Throw
        { $a.Add('s', 'k', 'v', '=') } | Should -Throw
        { $a.Set('k', 'v') } | Should -Throw
        { $a.Set('s', 'k', 'v') } | Should -Throw
        { $a.Remove('k') } | Should -Throw
        { $a.Remove('s', 'k') } | Should -Throw
        { $a.AddComment('t') } | Should -Throw
        { $a.AddComment('s', 't') } | Should -Throw
        { $a.AddSection('s') } | Should -Throw
        { $a.RemoveSection('s') } | Should -Throw
        { $a.Uncomment('t') } | Should -Throw
        { $a.UncommentPattern('p') } | Should -Throw
        { $a.UncommentPattern('p', $true) } | Should -Throw
        { $a.UncommentPattern('s', 'p') } | Should -Throw
        { $a.UncommentPattern('s', 'p', $true) } | Should -Throw
        { $a.Comment('t') } | Should -Throw
        { $a.CommentPattern('p') } | Should -Throw
        { $a.CommentPattern('p', $true) } | Should -Throw
        { $a.CommentPattern('s', 'p') } | Should -Throw
        { $a.CommentPattern('s', 'p', $true) } | Should -Throw
        { $a.ReplaceComment('o', 'n') } | Should -Throw
        { $a.SetInlineComment('k', 't') } | Should -Throw
        { $a.SetInlineComment('s', 'k', 't') } | Should -Throw
        { $a.RemoveInlineComment('k') } | Should -Throw
        { $a.RemoveInlineComment('s', 'k') } | Should -Throw
        { $a.Save() } | Should -Throw
        { $a.Save('p') } | Should -Throw
        { $a.ToString() } | Should -Throw
    }
}
