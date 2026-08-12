BeforeAll {
    $testsRoot = $PSScriptRoot
    while ((Split-Path $testsRoot -Leaf) -ne 'tests') { $testsRoot = Split-Path $testsRoot -Parent }
    Import-Module (Join-Path (Split-Path $testsRoot -Parent) 'src/PSIniToolbox/PSIniToolbox.psd1') -Force
}

Describe 'IniDocument parsing' {
    It 'Parse accepts an array of lines with the default inline mode' {
        $doc = [IniDocument]::Parse(@('[db]', 'host = localhost'))
        $doc.Sections['db']['host'] | Should -Be 'localhost'
    }

    It 'Load reads a file with the default inline mode' {
        $file = Join-Path $TestDrive 'load.ini'
        Set-Content -Path $file -Value "[db]`nhost = localhost" -Encoding utf8

        $doc = [IniDocument]::Load($file)
        $doc.Sections['db']['host'] | Should -Be 'localhost'
        $doc.Path | Should -Be $file
    }

    It 'stops sampling the comment symbol after ten comments' {
        $lines = 1..12 | ForEach-Object { "; comment $_" }
        $doc = [IniDocument]::Parse([string[]]$lines)
        $doc.CommentSymbol | Should -Be ';'
    }

    It 'parses key : value pairs and detects the colon delimiter' {
        $file = Join-Path $TestDrive 'colon.ini'
        Set-Content -Path $file -Value "host : localhost`nport : 5432" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.Sections['']['host'] | Should -Be 'localhost'
        $doc.Sections['']['port'] | Should -Be '5432'
        $doc.Delimiter | Should -Be ':'
    }

    It 'preserves the colon delimiter on save' {
        $file = Join-Path $TestDrive 'colon-save.ini'
        Set-Content -Path $file -Value "host: localhost`nport: 5432" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.ToString() | Should -Match 'host:'
        $doc.ToString() | Should -Not -Match 'host ='
    }

    It 'keeps a colon inside a value with an equals delimiter' {
        $file = Join-Path $TestDrive 'url.ini'
        Set-Content -Path $file -Value 'url = http://example.com:8080' -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.Sections['']['url'] | Should -Be 'http://example.com:8080'
        $doc.Delimiter | Should -Be '='
    }
}

Describe 'IniDocument editing' {
    It 'Get returns a value from a section' {
        $doc = @'
[database]
host = localhost
'@ | ConvertFrom-Ini
        $doc.Get('database', 'host') | Should -Be 'localhost'
    }

    It 'Get returns a top-level value without a section' {
        $doc = "appName = Demo" | ConvertFrom-Ini
        $doc.Get('appName') | Should -Be 'Demo'
    }

    It 'Get returns $null for a missing key or section' {
        $doc = New-IniDocument
        $doc.Get('missing') | Should -Be $null
        $doc.Get('nope', 'key') | Should -Be $null
    }

    It 'Get returns an array for repeated keys' {
        $doc = New-IniDocument
        $doc.Add('database', 'server', 'node-1')
        $doc.Add('database', 'server', 'node-2')
        $doc.Get('database', 'server') | Should -Be @('node-1', 'node-2')
    }

    It 'Set replaces existing values' {
        $doc = New-IniDocument
        $doc.Set('server', 'port', '80')
        $doc.Set('server', 'port', '8080')
        $doc.Sections['server']['port'] | Should -Be '8080'
    }

    It 'Set collapses repeated keys down to a single value' {
        $doc = New-IniDocument
        $doc.Add('db', 'server', 'a')
        $doc.Add('db', 'server', 'b')
        $doc.Set('db', 'server', 'only')
        $doc.Sections['db']['server'] | Should -Be 'only'
        (($doc.ToString() -split "`r?`n") | Where-Object { $_ -eq 'server = only' }).Count | Should -Be 1
    }

    It 'Add appends to existing values' {
        $doc = New-IniDocument
        $doc.Add('server', 'host', 'a')
        $doc.Add('server', 'host', 'b')
        $doc.Sections['server']['host'] | Should -Be @('a', 'b')
    }

    It 'Add inserts a repeated key right after the last existing instance' {
        $doc = New-IniDocument
        $doc.Add('s', 'extension', 'curl')
        $doc.Add('s', 'extension', 'zip')
        $doc.Set('s', 'other', 'x')
        $doc.Add('s', 'extension', 'imap')
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '=' }
        # imap lands right after zip, not at the end of the section after 'other'
        $lines | Should -Be @('extension = curl', 'extension = zip', 'extension = imap', 'other = x')
    }

    It 'Remove deletes a key from a section' {
        $doc = New-IniDocument
        $doc.Set('db', 'host', 'localhost')
        $doc.Set('db', 'port', '5432')
        $doc.Remove('db', 'host')
        $doc.Sections['db'].Contains('host') | Should -BeFalse
        $doc.Sections['db']['port'] | Should -Be '5432'
    }

    It 'Remove deletes all values of a repeated key' {
        $doc = New-IniDocument
        $doc.Add('db', 'server', 'a')
        $doc.Add('db', 'server', 'b')
        $doc.Remove('db', 'server')
        $doc.Sections['db'].Contains('server') | Should -BeFalse
    }

    It 'AddSection adds an empty section' {
        $doc = New-IniDocument
        $doc.AddSection('empty')
        $doc.Sections.Contains('empty') | Should -BeTrue
        ($doc.ToString() -split "`r?`n") | Should -Contain '[empty]'
    }

    It 'AddSection is idempotent for an existing section' {
        $doc = New-IniDocument
        $doc.Set('db', 'host', 'x')
        $doc.AddSection('db')
        @($doc.Lines | Where-Object { $_ -is [IniSectionLine] -and $_.Section -eq 'db' }).Count | Should -Be 1
    }

    It 'RemoveSection removes the section and its keys, leaving others intact' {
        $doc = New-IniDocument
        $doc.Set('keep', 'a', '1')
        $doc.Set('drop', 'b', '2')
        $doc.RemoveSection('drop')
        $doc.Sections.Contains('drop') | Should -BeFalse
        $doc.Sections['keep']['a'] | Should -Be '1'
        ($doc.ToString() -split "`r?`n") | Should -Not -Contain '[drop]'
    }

    It 'supports top-level entries via the no-section overloads' {
        $doc = New-IniDocument
        $doc.Set('a', '1')
        $doc.Add('b', 'x')
        $doc.Add('b', 'y')
        $doc.Sections['']['a'] | Should -Be '1'
        $doc.Sections['']['b'] | Should -Be @('x', 'y')
        $doc.Remove('a')
        $doc.Sections[''].Contains('a') | Should -BeFalse
    }

    It 'inserts a new top-level key ahead of the first section' {
        $doc = @'
[database]
host = localhost
'@ | ConvertFrom-Ini
        $doc.Set('appName', 'Demo')
        ($doc.ToString() -split "`r?`n")[0] | Should -Be 'appName = Demo'
    }

    It 'treats a literal [NoSection] header as an ordinary section' {
        $file = Join-Path $TestDrive 'nosection.ini'
        Set-Content -Path $file -Value "top = 1`n`n[NoSection]`nk = v" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.Sections['']['top'] | Should -Be '1'
        $doc.Sections['NoSection']['k'] | Should -Be 'v'
        ($doc.ToString() -split "`r?`n") | Should -Contain '[NoSection]'
    }

    It 'projects and serializes a section that has no header line' {
        $doc = New-IniDocument
        $doc.Lines.Add([IniKeyValueLine]::new($doc, 'orphan', 'k', 'v', '='))
        $doc.Set('orphan', 'k2', 'v2')
        $doc.Sections['orphan']['k'] | Should -Be 'v'
        ($doc.ToString() -split "`r?`n") | Should -Contain '[orphan]'
    }

    It 'AddComment without a leading marker uses the document CommentSymbol' {
        $doc = New-IniDocument
        $doc.AddComment('database', 'plain note')
        ($doc.ToString() -split "`r?`n") | Should -Contain '; plain note'
    }

    It 'Uncomment enables a matching commented key' {
        $doc = New-IniDocument
        $doc.AddComment('database', '; user = admin')
        $doc.UncommentPattern('user')
        $doc.Sections['database']['user'] | Should -Be 'admin'
    }

    It 'Uncomment ignores a leading comment marker in the input text' {
        $doc = New-IniDocument
        $doc.AddComment('database', '; host = localhost')
        $doc.AddComment('database', '# port = 5432')

        # Callers can paste the whole comment line, marker and all
        $doc.Uncomment('; host = localhost')
        $doc.Uncomment('# port = 5432')

        $doc.Sections['database']['host'] | Should -Be 'localhost'
        $doc.Sections['database']['port'] | Should -Be '5432'
    }

    It 'Uncomment only affects the exact matching line and leaves other comments intact' {
        $doc = New-IniDocument
        $doc.AddComment('db', '; host = localhost')
        $doc.AddComment('db', '; port = 5432')
        $doc.AddComment('db', '; a prose comment: with a colon')

        $doc.Uncomment('host = localhost')

        # The targeted line is uncommented ...
        $doc.Sections['db']['host'] | Should -Be 'localhost'
        # ... while the other commented lines stay commented and unchanged
        $doc.Sections['db'].Contains('port') | Should -BeFalse
        $lines = $doc.ToString() -split "`r?`n"
        $lines | Should -Contain '; port = 5432'
        $lines | Should -Contain '; a prose comment: with a colon'
    }

    It 'Uncomment distinguishes an indented example comment from the real directive' {
        $file = Join-Path $TestDrive 'indented-example.ini'
        Set-Content -Path $file -Value ";   extension=mysqli`n;extension=mysqli" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.Uncomment('extension=mysqli')

        # Only the real ";extension=mysqli" is uncommented; the indented example stays a comment
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match 'extension=mysqli' }
        $lines | Should -Be @(';   extension=mysqli', 'extension=mysqli')
    }

    It 'Uncomment enables a matching commented section header' {
        $doc = New-IniDocument
        $doc.AddComment('; [database]')
        $doc.UncommentPattern('database')
        $doc.Sections.Contains('database') | Should -BeTrue
        ($doc.ToString() -split "`r?`n") | Should -Contain '[database]'
    }

    It 'Uncommenting a section header re-scopes the following lines into it' {
        $doc = New-IniDocument
        $doc.Set('main', 'a', '1')
        $doc.AddComment('main', '; [advanced]')
        $doc.AddComment('main', '; timeout = 30')
        $doc.UncommentPattern('advanced')
        $doc.UncommentPattern('timeout')
        $doc.Sections['advanced']['timeout'] | Should -Be '30'
        $doc.Sections['main'].Contains('timeout') | Should -BeFalse
    }

    It 'Uncommenting a section header stops re-scoping at the next section' {
        $doc = New-IniDocument
        $doc.AddComment('; [alpha]')
        $doc.Set('beta', 'k', 'v')
        $doc.UncommentPattern('alpha')
        $doc.Sections.Contains('alpha') | Should -BeTrue
        $doc.Sections['beta']['k'] | Should -Be 'v'
    }

    It 'Comment converts a key/value line into a comment' {
        $doc = New-IniDocument
        $doc.Set('db', 'host', 'localhost')
        $doc.Set('db', 'port', '5432')
        $doc.CommentPattern('host')
        $doc.Sections['db'].Contains('host') | Should -BeFalse
        $doc.Sections['db']['port'] | Should -Be '5432'
        ($doc.ToString() -split "`r?`n") | Should -Contain '; host = localhost'
    }

    It 'Comment then Uncomment round-trips a key' {
        $doc = New-IniDocument
        $doc.Set('db', 'host', 'localhost')
        $doc.CommentPattern('host')
        $doc.UncommentPattern('host')
        $doc.Sections['db']['host'] | Should -Be 'localhost'
    }

    It 'CommentPattern matches the pattern as an unanchored substring of the whole line' {
        $doc = New-IniDocument
        $doc.Set('database', 'server', 'localhost')
        $doc.Set('database', 'port', '5432')
        $doc.Set('database', 'readOnlyHost', 'db.local')

        # 'host' is a substring of both 'localhost' (a value) and 'readOnlyHost' (a key)
        $doc.CommentPattern('host')

        $doc.Sections['database'].Contains('server') | Should -BeFalse
        $doc.Sections['database'].Contains('readOnlyHost') | Should -BeFalse
        $doc.Sections['database']['port'] | Should -Be '5432'

        $lines = $doc.ToString() -split "`r?`n"
        $lines | Should -Contain '; server = localhost'
        $lines | Should -Contain '; readOnlyHost = db.local'
        $lines | Should -Contain 'port = 5432'
    }

    It 'Anchoring the pattern to the key limits CommentPattern to the intended line' {
        $doc = New-IniDocument
        $doc.Set('database', 'server', 'localhost')
        $doc.Set('database', 'readOnlyHost', 'db.local')

        # Anchor to the start and the spaced delimiter so only a key named exactly 'server' matches
        $doc.CommentPattern('^server\s*=')

        $doc.Sections['database'].Contains('server') | Should -BeFalse
        $doc.Sections['database']['readOnlyHost'] | Should -Be 'db.local'

        $lines = $doc.ToString() -split "`r?`n"
        $lines | Should -Contain '; server = localhost'
        $lines | Should -Contain 'readOnlyHost = db.local'
    }

    It 'Comment matches the line as rendered, honoring DelimiterSpacing' {
        $doc = New-IniDocument
        $doc.DelimiterSpacing = [IniDelimiterSpacing]::None
        $doc.Set('db', 'host', 'localhost')

        # The line renders as 'host=localhost', so the exact-match Comment must use that form
        $doc.Comment('host = localhost') # spaced form no longer matches
        $doc.Sections['db'].Contains('host') | Should -BeTrue

        $doc.Comment('host=localhost')   # rendered form matches
        $doc.Sections['db'].Contains('host') | Should -BeFalse
        ($doc.ToString() -split "`r?`n") | Should -Contain '; host=localhost'
    }

    It 'CommentPattern scoped to a section leaves matching lines in other sections alone' {
        $doc = New-IniDocument
        $doc.Set('db', 'host', 'localhost')
        $doc.Set('web', 'host', '127.0.0.1')

        $doc.CommentPattern('db', 'host')

        $doc.Sections['db'].Contains('host') | Should -BeFalse
        $doc.Sections['web']['host'] | Should -Be '127.0.0.1'

        $lines = $doc.ToString() -split "`r?`n"
        $lines | Should -Contain '; host = localhost'
        $lines | Should -Contain 'host = 127.0.0.1'
    }

    It 'UncommentPattern scoped to a section leaves matching comments in other sections alone' {
        $doc = New-IniDocument
        $doc.AddComment('db', '; host = localhost')
        $doc.AddComment('web', '; host = 127.0.0.1')

        $doc.UncommentPattern('db', 'host')

        $doc.Sections['db']['host'] | Should -Be 'localhost'
        $doc.Sections['web'].Contains('host') | Should -BeFalse
        ($doc.ToString() -split "`r?`n") | Should -Contain '; host = 127.0.0.1'
    }

    It 'CommentPattern is case-insensitive by default and case-sensitive when passed $true' {
        $doc = New-IniDocument
        $doc.Set('db', 'Host', 'server-1')

        # Default is case-insensitive: 'host' matches key 'Host'
        $doc.CommentPattern('host')
        $doc.Sections['db'].Contains('Host') | Should -BeFalse

        $other = New-IniDocument
        $other.Set('db', 'Host', 'server-1')

        # Case-sensitive: 'host' does not match 'Host = server-1'
        $other.CommentPattern('host', $true)
        $other.Sections['db']['Host'] | Should -Be 'server-1'

        # Case-sensitive: exact case matches
        $other.CommentPattern('Host', $true)
        $other.Sections['db'].Contains('Host') | Should -BeFalse
    }

    It 'CommentPattern scoped and case-sensitive touches only exact-case keys in the section' {
        $doc = New-IniDocument
        $doc.Set('db', 'Host', 'server-1')
        $doc.Set('web', 'Host', 'server-2')
        $doc.CommentPattern('db', 'Host', $true)
        $doc.Sections['db'].Contains('Host') | Should -BeFalse
        $doc.Sections['web']['Host'] | Should -Be 'server-2'
    }

    It 'UncommentPattern global and case-sensitive matches only exact case' {
        $doc = New-IniDocument
        $doc.AddComment('db', '; Host = server-1')
        $doc.UncommentPattern('Host', $true)
        $doc.Sections['db']['Host'] | Should -Be 'server-1'
    }

    It 'UncommentPattern honors both the section scope and the case-sensitivity flag' {
        $doc = New-IniDocument
        $doc.AddComment('db', '; Host = server-1')

        # Case-sensitive, wrong case: no change
        $doc.UncommentPattern('db', 'host', $true)
        $doc.Sections['db'].Contains('Host') | Should -BeFalse

        # Case-sensitive, correct case within the scoped section: enabled
        $doc.UncommentPattern('db', 'Host', $true)
        $doc.Sections['db']['Host'] | Should -Be 'server-1'
    }

    It 'Comment converts a section header and reclassifies its lines to the previous section' {
        $doc = New-IniDocument
        $doc.Set('main', 'a', '1')
        $doc.Set('advanced', 'b', '2')
        $doc.CommentPattern('\[advanced\]')
        $doc.Sections.Contains('advanced') | Should -BeFalse
        $doc.Sections['main']['b'] | Should -Be '2'
        ($doc.ToString() -split "`r?`n") | Should -Contain '; [advanced]'
    }

    It 'Commenting a non-final section header re-scopes only up to the next section' {
        $doc = New-IniDocument
        $doc.Set('main', 'a', '1')
        $doc.Set('advanced', 'b', '2')
        $doc.CommentPattern('\[main\]')
        $doc.Sections.Contains('main') | Should -BeFalse
        $doc.Sections['']['a'] | Should -Be '1'
        $doc.Sections['advanced']['b'] | Should -Be '2'
    }

    It 'ReplaceComment swaps only the text after the marker' {
        $doc = New-IniDocument
        $doc.AddComment('; old note')
        $doc.ReplaceComment('old note', 'new note')
        $doc.ToString() | Should -Match '; new note'
        $doc.ToString() | Should -Not -Match 'old note'
    }

    It 'ReplaceComment ignores leading comment markers in either argument' {
        $doc = New-IniDocument
        $doc.AddComment('; old note')

        # Markers in both arguments are stripped; the line keeps its own ";" symbol
        $doc.ReplaceComment('; old note', '# new note')

        ($doc.ToString() -split "`r?`n") | Should -Contain '; new note'
        $doc.ToString() | Should -Not -Match 'old note'
    }
}

Describe 'SortSections' {
    It 'defaults to false and preserves insertion order' {
        $doc = New-IniDocument
        $doc.SortSections | Should -BeFalse
        $doc.Set('zebra', 'k', '1')
        $doc.Set('alpha', 'k', '2')
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '^\[' }
        $lines | Should -Be @('[zebra]', '[alpha]')
    }

    It 'sorts named sections alphabetically when enabled' {
        $doc = New-IniDocument
        $doc.Set('zebra', 'k', '1')
        $doc.Set('alpha', 'k', '2')
        $doc.Set('mango', 'k', '3')
        $doc.SortSections = $true
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '^\[' }
        $lines | Should -Be @('[alpha]', '[mango]', '[zebra]')
    }

    It 'keeps top-level keys before any sorted section' {
        $doc = New-IniDocument
        $doc.Set('top', 'value')
        $doc.Set('zebra', 'k', '1')
        $doc.Set('alpha', 'k', '2')
        $doc.SortSections = $true
        $out = $doc.ToString()
        $out.IndexOf('top') | Should -BeLessThan $out.IndexOf('[alpha]')
    }
}

Describe 'SortKeys' {
    It 'defaults to false and preserves insertion order' {
        $doc = New-IniDocument
        $doc.SortKeys | Should -BeFalse
        $doc.Set('server', 'zulu', '1')
        $doc.Set('server', 'alpha', '2')
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '=' }
        $lines | Should -Be @('zulu = 1', 'alpha = 2')
    }

    It 'sorts keys alphabetically within a section when enabled' {
        $doc = New-IniDocument
        $doc.Set('server', 'zulu', '1')
        $doc.Set('server', 'alpha', '2')
        $doc.Set('server', 'mango', '3')
        $doc.SortKeys = $true
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '=' }
        $lines | Should -Be @('alpha = 2', 'mango = 3', 'zulu = 1')
    }

    It 'keeps comments and blank lines in their original positions' {
        $doc = New-IniDocument
        $doc.Set('app', 'zulu', '1')
        $doc.AddComment('app', '; note')
        $doc.Set('app', 'alpha', '2')
        $doc.SortKeys = $true
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -ne '' -and $_ -ne '[app]' }
        $lines | Should -Be @('alpha = 2', '; note', 'zulu = 1')
    }
}

Describe 'StripComments' {
    It 'defaults to false and keeps comments' {
        $doc = New-IniDocument
        $doc.StripComments | Should -BeFalse
        $doc.AddComment('; keep me')
        $doc.ToString() | Should -Match 'keep me'
    }

    It 'omits all comments when enabled' {
        $doc = New-IniDocument
        $doc.AddComment('app', '; a note')
        $doc.Set('app', 'host', 'localhost')
        $doc.AddComment('app', '# another note')
        $doc.StripComments = $true
        $out = $doc.ToString()
        $out | Should -Not -Match 'note'
        $out | Should -Match 'host = localhost'
    }
}

Describe 'SectionSpacing' {
    It 'defaults to a single blank line between sections' {
        $doc = New-IniDocument
        $doc.SectionSpacing | Should -Be 1
        $doc.Set('first', 'k', '1')
        $doc.Set('second', 'k', '2')
        $lines = $doc.ToString() -split "`r?`n"
        $firstIdx = [array]::IndexOf($lines, '[first]')
        $secondIdx = [array]::IndexOf($lines, '[second]')
        ($secondIdx - $firstIdx) | Should -Be 3  # header, key, one blank
        $lines[$secondIdx - 1] | Should -Be ''
    }

    It 'writes the configured number of blank lines between sections' {
        $doc = New-IniDocument
        $doc.Set('first', 'k', '1')
        $doc.Set('second', 'k', '2')
        $doc.SectionSpacing = 2
        $lines = $doc.ToString() -split "`r?`n"
        $secondIdx = [array]::IndexOf($lines, '[second]')
        $lines[$secondIdx - 1] | Should -Be ''
        $lines[$secondIdx - 2] | Should -Be ''
        $lines[$secondIdx - 3] | Should -Not -Be ''
    }

    It 'places no blank line between sections when set to zero' {
        $doc = New-IniDocument
        $doc.Set('first', 'k', '1')
        $doc.Set('second', 'k', '2')
        $doc.SectionSpacing = 0
        $lines = $doc.ToString() -split "`r?`n"
        $secondIdx = [array]::IndexOf($lines, '[second]')
        $lines[$secondIdx - 1] | Should -Be 'k = 1'
    }

    It 'preserves existing blank lines when set to null' {
        $file = Join-Path $TestDrive 'spacing.ini'
        Set-Content -Path $file -Value "[first]`nk = 1`n`n`n`n[second]`nk = 2" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.SectionSpacing = $null
        $lines = $doc.ToString() -split "`r?`n"
        $firstIdx = [array]::IndexOf($lines, '[first]')
        $secondIdx = [array]::IndexOf($lines, '[second]')
        # header, key, then the three original blank lines
        ($secondIdx - $firstIdx) | Should -Be 5
    }
}

Describe 'PreserveDelimiters' {
    It 'defaults to false and normalizes mixed delimiters to Delimiter' {
        $file = Join-Path $TestDrive 'mixed-delim.ini'
        Set-Content -Path $file -Value "host = localhost`nport : 5432" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.PreserveDelimiters | Should -BeFalse
        $doc.Delimiter = '='
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '\S' }
        $lines | Should -Be @('host = localhost', 'port = 5432')
    }

    It 'keeps each property''s original delimiter when enabled' {
        $file = Join-Path $TestDrive 'preserve-delim.ini'
        Set-Content -Path $file -Value "host = localhost`nport : 5432" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.PreserveDelimiters = $true
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '\S' }
        $lines | Should -Be @('host = localhost', 'port : 5432')
    }

    It 'records the current Delimiter for new additions' {
        $doc = New-IniDocument
        $doc.Set('s', 'a', '1')
        $doc.Delimiter = ':'
        $doc.Set('s', 'b', '2')
        $doc.PreserveDelimiters = $true
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '=|:' }
        $lines | Should -Be @('a = 1', 'b : 2')
    }

    It 'tracks per-line delimiters for repeated keys' {
        $file = Join-Path $TestDrive 'repeat-delim.ini'
        Set-Content -Path $file -Value "server = a`nserver : b" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.PreserveDelimiters = $true
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '\S' }
        $lines | Should -Be @('server = a', 'server : b')
    }
}

Describe 'DelimiterSpacing' {
    It 'defaults to Spaces' {
        $doc = New-IniDocument
        $doc.DelimiterSpacing | Should -Be ([IniDelimiterSpacing]::Spaces)
        $doc.Set('s', 'k', 'v')
        ($doc.ToString() -split "`r?`n" | Where-Object { $_ -match '=' }) | Should -Be 'k = v'
    }

    It 'None writes no spaces around the delimiter' {
        $doc = New-IniDocument
        $doc.Set('s', 'k', 'v')
        $doc.DelimiterSpacing = [IniDelimiterSpacing]::None
        ($doc.ToString() -split "`r?`n" | Where-Object { $_ -match '=' }) | Should -Be 'k=v'
    }

    It 'Align pads keys so delimiters line up within a section' {
        $doc = New-IniDocument
        $doc.Set('db', 'host', 'localhost')
        $doc.Set('db', 'p', '5432')
        $doc.DelimiterSpacing = [IniDelimiterSpacing]::Align
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '=' }
        $lines | Should -Be @('host = localhost', 'p    = 5432')
    }

    It 'Align aligns each section independently' {
        $doc = New-IniDocument
        $doc.Set('a', 'x', '1')
        $doc.Set('b', 'longkey', '2')
        $doc.DelimiterSpacing = [IniDelimiterSpacing]::Align
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '=' }
        $lines | Should -Be @('x = 1', 'longkey = 2')
    }

    It 'Align recalculates the cached width when a longer key is added' {
        $doc = New-IniDocument
        $doc.DelimiterSpacing = [IniDelimiterSpacing]::Align
        $doc.Set('s', 'a', '1')
        $doc.Set('s', 'longer', '2')
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '=' }
        $lines[0].IndexOf('=') | Should -Be $lines[1].IndexOf('=')
        $lines[1] | Should -Be 'longer = 2'
    }
}

Describe 'PreserveDelimiterSpacing' {
    It 'defaults to false for a new document and true for a parsed one' {
        (New-IniDocument).PreserveDelimiterSpacing | Should -BeFalse

        $file = Join-Path $TestDrive 'delim-spacing-default.ini'
        Set-Content -Path $file -Value "a = 1" -Encoding utf8
        (Get-IniContent -Path $file).PreserveDelimiterSpacing | Should -BeTrue
    }

    It 'lets the document DelimiterSpacing govern every line when disabled' {
        $file = Join-Path $TestDrive 'delim-spacing.ini'
        Set-Content -Path $file -Value "a=1`nb = 2`nc    =    3" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.PreserveDelimiterSpacing = $false
        $doc.DelimiterSpacing = [IniDelimiterSpacing]::Spaces
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '\S' }
        $lines | Should -Be @('a = 1', 'b = 2', 'c = 3')
    }

    It 'keeps each line''s own detected spacing when enabled' {
        $file = Join-Path $TestDrive 'preserve-delim-spacing.ini'
        Set-Content -Path $file -Value "a=1`nb = 2`nlongkey    =    3" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.PreserveDelimiterSpacing = $true
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '\S' }
        # a=1 -> None, b = 2 -> Spaces, longkey (multiple spaces before) -> Align (padded to section width)
        $lines | Should -Be @('a=1', 'b = 2', 'longkey = 3')
    }

    It 'detects and preserves asymmetric spacing when enabled' {
        $file = Join-Path $TestDrive 'asym-delim-spacing.ini'
        Set-Content -Path $file -Value "a =1`nb= 2" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.PreserveDelimiterSpacing = $true
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '\S' }
        $lines | Should -Be @('a =1', 'b= 2')
    }

    It 'preserves the delimiter spacing of a line uncommented from a comment' {
        $file = Join-Path $TestDrive 'uncomment-spacing.ini'
        Set-Content -Path $file -Value ";cgi.fix_pathinfo=1`n;host = localhost" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.Uncomment('cgi.fix_pathinfo=1')
        $doc.Uncomment('host = localhost')
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '\S' }
        $lines | Should -Be @('cgi.fix_pathinfo=1', 'host = localhost')
    }

    It 'inherits the document spacing when uncommenting an empty-value line' {
        $file = Join-Path $TestDrive 'uncomment-empty-value.ini'
        # The commented line has a space before "=" and no value, so its spacing cannot be detected
        Set-Content -Path $file -Value ";session.cookie_secure =" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.DelimiterSpacing = [IniDelimiterSpacing]::Spaces
        $doc.Uncomment('session.cookie_secure =')
        # Giving it a value later renders with the document's Spaces style, not SpaceLeft
        $doc.Set('', 'session.cookie_secure', 'On')
        ($doc.ToString() -split "`r?`n" | Where-Object { $_ -match 'cookie_secure' }) | Should -Be 'session.cookie_secure = On'
    }

    It 'parses an empty-value line with the document spacing rather than its own' {
        $file = Join-Path $TestDrive 'parse-empty-value.ini'
        # "a =" has a space before "=" and no value, so its own spacing must not be preserved;
        # the other lines make Spaces the document's detected style
        Set-Content -Path $file -Value "a =`nb = 2`nc = 3" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.PreserveDelimiterSpacing | Should -BeTrue
        # Setting a value later renders with the document's Spaces style, not SpaceLeft ("a =On")
        $doc.Set('', 'a', 'On')
        ($doc.ToString() -split "`r?`n" | Where-Object { $_ -match '^a ' }) | Should -Be 'a = On'
    }

    It 'classifies spacing from space counts on each side of the delimiter' {
        [IniKeyValueLine]::DetectSpacing(0, 0) | Should -Be ([IniDelimiterSpacing]::None)
        [IniKeyValueLine]::DetectSpacing(1, 1) | Should -Be ([IniDelimiterSpacing]::Spaces)
        [IniKeyValueLine]::DetectSpacing(1, 0) | Should -Be ([IniDelimiterSpacing]::SpaceLeft)
        [IniKeyValueLine]::DetectSpacing(0, 1) | Should -Be ([IniDelimiterSpacing]::SpaceRight)
        [IniKeyValueLine]::DetectSpacing(3, 2) | Should -Be ([IniDelimiterSpacing]::Align)
    }
}

Describe 'PreserveCommentSymbols' {
    It 'defaults to false and normalizes mixed symbols to CommentSymbol' {
        $file = Join-Path $TestDrive 'symbols.ini'
        Set-Content -Path $file -Value "; one`n# two" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.PreserveCommentSymbols | Should -BeFalse
        $doc.CommentSymbol = ';'
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '\S' }
        $lines | Should -Be @('; one', '; two')
    }

    It 'keeps each comment''s original symbol when enabled' {
        $file = Join-Path $TestDrive 'preserve-symbols.ini'
        Set-Content -Path $file -Value "; one`n# two" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.PreserveCommentSymbols = $true
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '\S' }
        $lines | Should -Be @('; one', '# two')
    }

    It 'auto-detects the majority comment symbol on load' {
        $file = Join-Path $TestDrive 'majority-symbol.ini'
        Set-Content -Path $file -Value "# a`n# b`n; c" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.CommentSymbol | Should -Be '#'
    }
}

Describe 'PreserveCommentSpacing' {
    It 'normalizes comment spacing to a single space when disabled' {
        $file = Join-Path $TestDrive 'spacing.ini'
        Set-Content -Path $file -Value ";;;;;`n;   spaced out`n; normal" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.PreserveCommentSpacing = $false
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '\S' }
        $lines | Should -Be @(';;;;;', '; spaced out', '; normal')
    }

    It 'keeps the original number of spaces after the marker when enabled' {
        $file = Join-Path $TestDrive 'preserve-spacing.ini'
        Set-Content -Path $file -Value ";;;;;`n;   spaced out`n; normal" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.PreserveCommentSpacing = $true
        $lines = ($doc.ToString() -split "`r?`n") | Where-Object { $_ -match '\S' }
        $lines | Should -Be @(';;;;;', ';   spaced out', '; normal')
    }

    It 'records one space for programmatically added comments' {
        $doc = New-IniDocument
        $doc.AddComment('s', 'hello')
        $doc.PreserveCommentSpacing = $true
        ($doc.ToString() -split "`r?`n") | Should -Contain '; hello'
    }
}

Describe 'Inline comments' {
    It 'keeps values verbatim by default (None)' {
        $doc = "host = localhost ; note" | ConvertFrom-Ini
        $doc.Sections['']['host'] | Should -Be 'localhost ; note'
    }

    It 'splits at the first symbol with First mode' {
        $doc = "host = localhost ; note" | ConvertFrom-Ini -InlineCommentMode First
        $doc.Sections['']['host'] | Should -Be 'localhost'
        $kv = $doc.Lines | Where-Object { $_ -is [IniKeyValueLine] }
        $kv.InlineComment.Content | Should -Be 'note'
        ($doc.ToString() -split "`r?`n") | Should -Contain 'host = localhost  ; note'
    }

    It 'splits at the last symbol with Last mode' {
        $doc = "path = a;b ; note" | ConvertFrom-Ini -InlineCommentMode Last
        $doc.Sections['']['path'] | Should -Be 'a;b'
        ($doc.Lines | Where-Object { $_ -is [IniKeyValueLine] }).InlineComment.Content | Should -Be 'note'
    }

    It 'parses an inline comment on a section header' {
        $doc = "[db] ; main" | ConvertFrom-Ini -InlineCommentMode First
        $section = $doc.Lines | Where-Object { $_ -is [IniSectionLine] }
        $section.InlineComment.Content | Should -Be 'main'
        ($doc.ToString() -split "`r?`n") | Should -Contain '[db]  ; main'
    }

    It 'parses a section header inline comment at the last symbol in Last mode' {
        $doc = '[db] ; a ; main' | ConvertFrom-Ini -InlineCommentMode Last
        $section = $doc.Lines | Where-Object { $_ -is [IniSectionLine] }
        $section.InlineComment.Content | Should -Be 'main'
    }

    It 'StripComments drops inline comments' {
        $doc = "host = localhost ; note" | ConvertFrom-Ini -InlineCommentMode First
        $doc.StripComments = $true
        ($doc.ToString() -split "`r?`n") | Should -Contain 'host = localhost'
    }

    It 'SetInlineComment adds an inline comment' {
        $doc = New-IniDocument
        $doc.Set('db', 'host', 'localhost')
        $doc.SetInlineComment('db', 'host', '; the host')
        ($doc.ToString() -split "`r?`n") | Should -Contain 'host = localhost  ; the host'
    }

    It 'SetInlineComment works without a section (top-level)' {
        $doc = New-IniDocument
        $doc.Set('host', 'localhost')
        $doc.SetInlineComment('host', '; primary')
        ($doc.ToString() -split "`r?`n") | Should -Contain 'host = localhost  ; primary'
    }

    It 'SetInlineComment with empty text clears the inline comment' {
        $doc = 'host = localhost ; note' | ConvertFrom-Ini -InlineCommentMode First
        $doc.SetInlineComment('', 'host', '')
        ($doc.ToString() -split "`r?`n") | Should -Contain 'host = localhost'
    }

    It 'RemoveInlineComment clears an inline comment in a section' {
        $doc = @'
[database]
host = localhost ; primary
'@ | ConvertFrom-Ini -InlineCommentMode First
        $doc.RemoveInlineComment('database', 'host')
        ($doc.ToString() -split "`r?`n") | Should -Contain 'host = localhost'
        $doc.ToString() | Should -Not -Match 'primary'
    }

    It 'RemoveInlineComment works without a section (top-level)' {
        $doc = "host = localhost ; primary" | ConvertFrom-Ini -InlineCommentMode First
        $doc.RemoveInlineComment('host')
        ($doc.ToString() -split "`r?`n") | Should -Contain 'host = localhost'
        $doc.ToString() | Should -Not -Match 'primary'
    }
}

Describe 'IniDocument Save' {
    It 'Save() with no argument writes back to the loaded path' {
        $file = Join-Path $TestDrive 'save-back.ini'
        Set-Content -Path $file -Value "[db]`nhost = localhost" -Encoding utf8

        $doc = Get-IniContent -Path $file
        $doc.Set('db', 'host', 'changed')
        $doc.Save()

        (Get-IniContent -Path $file).Sections['db']['host'] | Should -Be 'changed'
    }

    It 'Save() throws when the document has no path' {
        { (New-IniDocument).Save() } | Should -Throw
    }

    It 'Save(path) writes to and remembers a specific file' {
        $doc = New-IniDocument
        $doc.Set('app', 'name', 'Demo')
        $out = Join-Path $TestDrive 'save-as.ini'

        $doc.Save($out)

        $doc.Path | Should -Be $out
        (Get-IniContent -Path $out).Sections['app']['name'] | Should -Be 'Demo'
    }
}

Describe 'IniDocument preconditions' {
    It 'Set rejects an empty key' {
        { (New-IniDocument).Set('', 'value') } | Should -Throw -ExpectedMessage '*Key cannot be null or empty*'
    }

    It 'Set rejects a null key' {
        { (New-IniDocument).Set($null, 'value') } | Should -Throw
    }

    It 'Set rejects an empty key within a section' {
        { (New-IniDocument).Set('db', '', 'value') } | Should -Throw
    }

    It 'Set allows an empty value' {
        $doc = New-IniDocument
        { $doc.Set('db', 'host', '') } | Should -Not -Throw
        $doc.Sections['db']['host'] | Should -Be ''
    }

    It 'Add rejects an empty or null key' {
        { (New-IniDocument).Add('', 'value') } | Should -Throw
        { (New-IniDocument).Add('db', $null, 'value') } | Should -Throw
    }

    It 'Get rejects an empty or null key' {
        { (New-IniDocument).Get('') } | Should -Throw
        { (New-IniDocument).Get('db', $null) } | Should -Throw
    }

    It 'Remove rejects an empty key' {
        { (New-IniDocument).Remove('') } | Should -Throw
    }

    It 'AddSection rejects an empty or null name' {
        { (New-IniDocument).AddSection('') } | Should -Throw -ExpectedMessage '*Section name cannot be null or empty*'
        { (New-IniDocument).AddSection($null) } | Should -Throw
    }

    It 'RemoveSection rejects an empty name' {
        { (New-IniDocument).RemoveSection('') } | Should -Throw
    }

    It 'CommentPattern rejects an empty pattern (which would otherwise match every line)' {
        { (New-IniDocument).CommentPattern('') } | Should -Throw -ExpectedMessage '*Pattern cannot be null or empty*'
        { (New-IniDocument).CommentPattern('db', '') } | Should -Throw
    }

    It 'UncommentPattern rejects an empty pattern' {
        { (New-IniDocument).UncommentPattern('') } | Should -Throw
        { (New-IniDocument).UncommentPattern('db', '') } | Should -Throw
    }

    It 'Comment and Uncomment reject empty text' {
        { (New-IniDocument).Comment('') } | Should -Throw
        { (New-IniDocument).Uncomment('') } | Should -Throw
    }

    It 'ReplaceComment rejects an empty OldText' {
        { (New-IniDocument).ReplaceComment('', 'new') } | Should -Throw
    }

    It 'SetInlineComment rejects an empty key' {
        { (New-IniDocument).SetInlineComment('db', '', '; note') } | Should -Throw
        { (New-IniDocument).SetInlineComment('', '; note') } | Should -Throw
    }

    It 'RemoveInlineComment rejects an empty key' {
        { (New-IniDocument).RemoveInlineComment('') } | Should -Throw
    }

    It 'Save rejects an empty path' {
        { (New-IniDocument).Save('') } | Should -Throw -ExpectedMessage '*FilePath cannot be null or empty*'
    }
}

