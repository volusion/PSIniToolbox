class IniDocument : AbstractIniDocument {
    IniDocument() {
        $this.Lines = [System.Collections.Generic.List[AbstractIniLine]]::new()
        $this.RebuildSections()
    }

    static [IniDocument] Parse([string[]]$Lines, [IniInlineCommentMode]$InlineCommentMode) {
        $doc = [IniDocument]::new()
        $doc.InlineCommentMode = $InlineCommentMode
        # Documents built by parsing existing content preserve its original spacing; New-IniDocument normalizes
        $doc.PreserveDelimiterSpacing = $true
        $doc.PreserveCommentSpacing = $true
        $currentSection = ""

        # Sample the first 10 key/value separators to auto-detect the spacing and delimiter style
        $sampledSeparators = 0
        $spacedSeparators = 0
        $colonSeparators = 0

        # Detect the comment symbol up front so inline-comment parsing can use it
        $sampledComments = 0
        $hashComments = 0
        foreach ($probe in $Lines) {
            if ($probe -match "^\s*([;#])") {
                $sampledComments++
                if ($matches[1] -eq "#") { $hashComments++ }
                if ($sampledComments -ge 10) { break }
            }
        }
        if ($sampledComments -gt 0 -and ($hashComments * 2) -gt $sampledComments) {
            $doc.CommentSymbol = "#"
        }
        $symbol = $doc.CommentSymbol
        $mode = $doc.InlineCommentMode

        switch -regex ($Lines) {
            # Match blank lines
            "^\s*$" {
                $doc.Lines.Add([IniBlankLine]::new($doc, $currentSection))
                continue
            }
            # Match comments (starts with ; or #)
            "^\s*([;#])( *)(.*)" {
                $doc.Lines.Add([IniCommentLine]::new($doc, $currentSection, $matches[1], $matches[3], $matches[2].Length))
                continue
            }
            # Match sections [SectionName] with optional trailing inline comment
            "^\s*\[(.+?)\]\s*(.*)$" {
                $currentSection = $matches[1].Trim()
                $sectionLine = [IniSectionLine]::new($doc, $currentSection)
                if ($mode -ne [IniInlineCommentMode]::None -and $matches[2]) {
                    $trailing = $matches[2]
                    $idx = if ($mode -eq [IniInlineCommentMode]::First) { $trailing.IndexOf($symbol) } else { $trailing.LastIndexOf($symbol) }
                    if ($idx -ge 0) {
                        $sectionLine.InlineComment = [IniComment]::Parse($trailing.Substring($idx))
                    }
                }
                $doc.Lines.Add($sectionLine)
                continue
            }
            # Match key = value or key : value pairs
            "^\s*(.+?)( *)([:=])( *)(.*)" {
                $name = $matches[1].Trim()
                $foundDelimiter = $matches[3]
                $value = $matches[5].Trim()
                $spacing = [IniKeyValueLine]::DetectSpacing($matches[2].Length, $matches[4].Length)
                $inline = $null
                if ($mode -ne [IniInlineCommentMode]::None) {
                    $idx = if ($mode -eq [IniInlineCommentMode]::First) { $value.IndexOf($symbol) } else { $value.LastIndexOf($symbol) }
                    if ($idx -ge 0) {
                        $inline = [IniComment]::Parse($value.Substring($idx))
                        $value = $value.Substring(0, $idx).Trim()
                    }
                }
                $kv = [IniKeyValueLine]::new($doc, $currentSection, $name, $value, $foundDelimiter)
                $kv.DelimiterSpacing = $spacing
                $kv.InlineComment = $inline
                $doc.Lines.Add($kv)
                if ($sampledSeparators -lt 10) {
                    $sampledSeparators++
                    if ($_ -match "\s[:=]\s") { $spacedSeparators++ }
                    if ($foundDelimiter -eq ":") { $colonSeparators++ }
                }
                continue
            }
        }

        # Spaced separators win only if they are the majority of the sample
        if ($sampledSeparators -gt 0) {
            $doc.DelimiterSpacing = if (($spacedSeparators * 2) -gt $sampledSeparators) {
                [IniDelimiterSpacing]::Spaces
            }
            else {
                [IniDelimiterSpacing]::None
            }
            # Colon wins as the delimiter only if it is the majority of the sample
            if (($colonSeparators * 2) -gt $sampledSeparators) {
                $doc.Delimiter = ":"
            }
        }

        # Empty-value lines have no trailing spacing to detect, so they follow the document's DelimiterSpacing
        foreach ($line in $doc.Lines) {
            if ($line.IsKeyValue() -and $line.Value -eq "") {
                $line.DelimiterSpacing = $doc.DelimiterSpacing
            }
        }

        $doc.RebuildSections()
        return $doc
    }

    static [IniDocument] Parse([string[]]$Lines) {
        return [IniDocument]::Parse($Lines, [IniInlineCommentMode]::None)
    }

    static [IniDocument] Load([string]$FilePath, [IniInlineCommentMode]$InlineCommentMode) {
        $doc = [IniDocument]::Parse([System.IO.File]::ReadAllLines($FilePath), $InlineCommentMode)
        $doc.Path = $FilePath
        return $doc
    }

    static [IniDocument] Load([string]$FilePath) {
        return [IniDocument]::Load($FilePath, [IniInlineCommentMode]::None)
    }

    # Index of the last line owned by a section, or -1 if the section has no lines yet
    hidden [int] LastIndexOfSection([string]$Section) {
        for ($i = $this.Lines.Count - 1; $i -ge 0; $i--) {
            if ($this.Lines[$i].Section -eq $Section) {
                return $i
            }
        }
        return -1
    }

    # Index of the last key/value line for a key within a section, or -1 if the key is not present
    hidden [int] LastIndexOfKey([string]$Section, [string]$Key) {
        for ($i = $this.Lines.Count - 1; $i -ge 0; $i--) {
            $line = $this.Lines[$i]
            if ($line.IsKeyValue() -and $line.Section -eq $Section -and $line.Key -eq $Key) {
                return $i
            }
        }
        return -1
    }

    # Insert a line at the end of its section, creating a section header for new named sections
    hidden [void] AppendLine([AbstractIniLine]$Line) {
        $section = $Line.Section
        $idx = $this.LastIndexOfSection($section)
        if ($idx -ge 0) {
            $this.Lines.Insert($idx + 1, $Line)
        }
        elseif ($section -eq "") {
            # Reached only when no top-level line exists yet, so every existing line belongs to a
            # section; insert ahead of them all to keep top-level entries first.
            $this.Lines.Insert(0, $Line)
        }
        else {
            $this.Lines.Add([IniSectionLine]::new($this, $section))
            $this.Lines.Add($Line)
        }
    }

    # Rebuild the Sections read projection and per-section key-width cache from the line list
    hidden [void] RebuildSections() {
        $proj = [ordered]@{}
        $proj[""] = [ordered]@{}
        $widths = [System.Collections.Generic.Dictionary[string, int]]::new()

        foreach ($line in $this.Lines) {
            if ($line.IsSection()) {
                if (-not $proj.Contains($line.Section)) {
                    $proj[$line.Section] = [ordered]@{}
                }
            }
            elseif ($line.IsKeyValue()) {
                $sec = $line.Section
                # The width cache tracks every key in the section, regardless of disabled state
                if (-not $widths.ContainsKey($sec)) {
                    $widths[$sec] = 0
                }
                if ($line.Key.Length -gt $widths[$sec]) {
                    $widths[$sec] = $line.Key.Length
                }

                if (-not $line.IsDisabled) {
                    if (-not $proj.Contains($sec)) {
                        $proj[$sec] = [ordered]@{}
                    }
                    if ($proj[$sec].Contains($line.Key)) {
                        $proj[$sec][$line.Key] = @($proj[$sec][$line.Key]) + $line.Value
                    }
                    else {
                        $proj[$sec][$line.Key] = $line.Value
                    }
                }
            }
        }

        $this.Sections = $proj
        $this.KeyWidths = $widths
    }

    # When $Scoped is true, only lines belonging to $Section are considered
    hidden [void] CommentWhere([scriptblock]$Predicate, [bool]$Scoped, [string]$Section) {
        for ($i = 0; $i -lt $this.Lines.Count; $i++) {
            $line = $this.Lines[$i]
            if ($Scoped -and $line.Section -ne $Section) { continue }

            if ($line.IsKeyValue()) {
                # Match and store the line exactly as it renders (delimiter, spacing, inline comment)
                $lineContent = $line.ToString()
                if (& $Predicate $lineContent) {
                    $this.Lines[$i] = [IniCommentLine]::new($this, $line.Section, $this.CommentSymbol, $lineContent)
                }
            }
            elseif ($line.IsSection()) {
                $lineContent = $line.ToString()
                if (& $Predicate $lineContent) {
                    # The section's lines fall back to the enclosing (previous) section
                    $previousSection = ""
                    for ($k = $i - 1; $k -ge 0; $k--) {
                        if ($this.Lines[$k].IsSection()) {
                            $previousSection = $this.Lines[$k].Section
                            break
                        }
                    }
                    for ($j = $i + 1; $j -lt $this.Lines.Count; $j++) {
                        if ($this.Lines[$j].IsSection()) { break }
                        $this.Lines[$j].Section = $previousSection
                    }
                    $this.Lines[$i] = [IniCommentLine]::new($this, $previousSection, $this.CommentSymbol, $lineContent)
                }
            }
        }
        $this.RebuildSections()
    }

    # When $Scoped is true, only lines belonging to $Section are considered
    hidden [void] UncommentWhere([scriptblock]$Predicate, [bool]$Scoped, [string]$Section) {
        for ($i = 0; $i -lt $this.Lines.Count; $i++) {
            $line = $this.Lines[$i]
            if (-not $line.IsCommentText()) { continue }
            if ($Scoped -and $line.Section -ne $Section) { continue }

            # Content is marker-free; MatchKey normalizes the single separator space for exact matching
            $lineContent = $line.Comment.Content
            $matchKey = $line.Comment.MatchKey()
            if (-not (& $Predicate $matchKey)) { continue }

            if ($lineContent -match "^\s*\[(.+)\]\s*$") {
                # Uncomment a section header and re-scope the following lines into it
                $name = $matches[1].Trim()
                $this.Lines[$i] = [IniSectionLine]::new($this, $name)
                for ($j = $i + 1; $j -lt $this.Lines.Count; $j++) {
                    if ($this.Lines[$j].IsSection()) { break }
                    $this.Lines[$j].Section = $name
                }
            }
            elseif ($lineContent -match "^\s*(.+?)( *)([:=])( *)(.*)") {
                # Uncomment a key/value line in place, preserving its original delimiter spacing
                $uncommentedValue = $matches[5].Trim()
                $kv = [IniKeyValueLine]::new($this, $line.Section, $matches[1].Trim(), $uncommentedValue, $matches[3])
                # With no value there is no trailing spacing to detect, so inherit the document's setting
                $kv.DelimiterSpacing = if ($uncommentedValue -eq "") {
                    $this.DelimiterSpacing
                }
                else {
                    [IniKeyValueLine]::DetectSpacing($matches[2].Length, $matches[4].Length)
                }
                $this.Lines[$i] = $kv
            }
        }
        $this.RebuildSections()
    }

    # Add a value while recording a specific delimiter for that line (used by the parser)
    [void] Add([string]$Section, [string]$Key, [string]$Value, [string]$LineDelimiter) {
        if ([string]::IsNullOrEmpty($Key)) {
            throw [System.ArgumentException]::new('Key cannot be null or empty.', 'Key')
        }
        $line = [IniKeyValueLine]::new($this, $Section, $Key, $Value, $LineDelimiter)
        # Keep repeated keys together: insert right after the last existing instance of the key
        $keyIdx = $this.LastIndexOfKey($Section, $Key)
        if ($keyIdx -ge 0) {
            $this.Lines.Insert($keyIdx + 1, $line)
        }
        else {
            $this.AppendLine($line)
        }
        $this.RebuildSections()
    }

    # Add a value to a key in a section; repeated keys collect into an array of values.
    # New additions record the document's current Delimiter as their original delimiter.
    [void] Add([string]$Section, [string]$Key, [string]$Value) {
        $this.Add($Section, $Key, $Value, $this.Delimiter)
    }

    # Add a top-level value (no section) using the current Delimiter
    [void] Add([string]$Key, [string]$Value) {
        $this.Add("", $Key, $Value)
    }

    # Append a comment line to a section. The text may include a leading ";" or "#" marker,
    # which is split off into the comment symbol; otherwise the document's CommentSymbol is used.
    [void] AddComment([string]$Section, [string]$Text) {
        if ($Text -match "^\s*([;#])( *)(.*)$") {
            $symbol = $matches[1]
            $spaceCount = $matches[2].Length
            $content = $matches[3]
        }
        else {
            $symbol = $this.CommentSymbol
            $spaceCount = 1
            $content = $Text
        }
        $this.AppendLine([IniCommentLine]::new($this, $Section, $symbol, $content, $spaceCount))
        $this.RebuildSections()
    }

    # Append a top-level comment (no section)
    [void] AddComment([string]$Text) {
        $this.AddComment("", $Text)
    }

    # Add an empty section header if the section does not already exist
    [void] AddSection([string]$Section) {
        if ([string]::IsNullOrEmpty($Section)) {
            throw [System.ArgumentException]::new('Section name cannot be null or empty.', 'Section')
        }
        if ($this.LastIndexOfSection($Section) -lt 0) {
            $this.Lines.Add([IniSectionLine]::new($this, $Section))
            $this.RebuildSections()
        }
    }

    # Comment out a key/value or section line by exact, case-sensitive text
    [void] Comment([string]$Text) {
        if ([string]::IsNullOrEmpty($Text)) {
            throw [System.ArgumentException]::new('Text cannot be null or empty.', 'Text')
        }
        $this.CommentWhere({ param($line) $line -ceq $Text }, $false, "")
    }

    # Comment out matching lines only within a specific section
    [void] CommentPattern([string]$Section, [string]$Pattern, [bool]$CaseSensitive) {
        if ([string]::IsNullOrEmpty($Pattern)) {
            throw [System.ArgumentException]::new('Pattern cannot be null or empty.', 'Pattern')
        }
        if ($CaseSensitive) {
            $this.CommentWhere({ param($line) $line -cmatch $Pattern }, $true, $Section)
        }
        else {
            $this.CommentWhere({ param($line) $line -imatch $Pattern }, $true, $Section)
        }
    }

    [void] CommentPattern([string]$Section, [string]$Pattern) {
        $this.CommentPattern($Section, $Pattern, $false)
    }

    # Comment out key/value or section lines whose text matches a regex pattern (case-insensitive by default).
    # Pass $true for $CaseSensitive to match case-sensitively (-cmatch)
    [void] CommentPattern([string]$Pattern, [bool]$CaseSensitive) {
        if ([string]::IsNullOrEmpty($Pattern)) {
            throw [System.ArgumentException]::new('Pattern cannot be null or empty.', 'Pattern')
        }
        if ($CaseSensitive) {
            $this.CommentWhere({ param($line) $line -cmatch $Pattern }, $false, "")
        }
        else {
            $this.CommentWhere({ param($line) $line -imatch $Pattern }, $false, "")
        }
    }

    [void] CommentPattern([string]$Pattern) {
        $this.CommentPattern($Pattern, $false)
    }

    # Get a key's value from a section; returns $null if absent, or an array for repeated keys
    [object] Get([string]$Section, [string]$Key) {
        if ([string]::IsNullOrEmpty($Key)) {
            throw [System.ArgumentException]::new('Key cannot be null or empty.', 'Key')
        }
        if ($this.Sections.Contains($Section) -and $this.Sections[$Section].Contains($Key)) {
            return $this.Sections[$Section][$Key]
        }
        return $null
    }

    # Get a top-level (no-section) key's value
    [object] Get([string]$Key) {
        return $this.Get("", $Key)
    }

    # Remove a key and all of its values from a section
    [void] Remove([string]$Section, [string]$Key) {
        if ([string]::IsNullOrEmpty($Key)) {
            throw [System.ArgumentException]::new('Key cannot be null or empty.', 'Key')
        }
        for ($i = $this.Lines.Count - 1; $i -ge 0; $i--) {
            $line = $this.Lines[$i]
            if ($line.IsKeyValue() -and $line.Section -eq $Section -and $line.Key -eq $Key) {
                $this.Lines.RemoveAt($i)
            }
        }
        $this.RebuildSections()
    }

    # Remove a top-level key (no section)
    [void] Remove([string]$Key) {
        $this.Remove("", $Key)
    }

    # Clear the inline comment on a key/value line, if it has one
    [void] RemoveInlineComment([string]$Section, [string]$Key) {
        if ([string]::IsNullOrEmpty($Key)) {
            throw [System.ArgumentException]::new('Key cannot be null or empty.', 'Key')
        }
        foreach ($line in $this.Lines) {
            if ($line.IsKeyValue() -and $line.Section -eq $Section -and $line.Key -eq $Key) {
                $line.InlineComment = $null
                break
            }
        }
    }

    # Clear a top-level (no-section) key's inline comment
    [void] RemoveInlineComment([string]$Key) {
        $this.RemoveInlineComment("", $Key)
    }

    # Remove a section and every line that belongs to it, leaving other sections untouched
    [void] RemoveSection([string]$Section) {
        if ([string]::IsNullOrEmpty($Section)) {
            throw [System.ArgumentException]::new('Section name cannot be null or empty.', 'Section')
        }
        for ($i = $this.Lines.Count - 1; $i -ge 0; $i--) {
            if ($this.Lines[$i].Section -eq $Section) {
                $this.Lines.RemoveAt($i)
            }
        }
        $this.RebuildSections()
    }

    # Replace a comment's text (case-sensitive match on the content after the marker).
    # A leading ";"/"#" marker in either argument is ignored; the line keeps its own symbol.
    [void] ReplaceComment([string]$OldText, [string]$NewText) {
        if ([string]::IsNullOrEmpty($OldText)) {
            throw [System.ArgumentException]::new('OldText cannot be null or empty.', 'OldText')
        }
        $oldContent = [IniComment]::Parse($OldText).Content
        $newContent = [IniComment]::Parse($NewText).Content
        foreach ($line in $this.Lines) {
            if ($line.IsCommentText() -and $line.Comment.Content -ceq $oldContent) {
                $line.Comment.Content = $newContent
            }
        }
    }

    [void] Save([string]$FilePath) {
        if ([string]::IsNullOrEmpty($FilePath)) {
            throw [System.ArgumentException]::new('FilePath cannot be null or empty.', 'FilePath')
        }
        # Remember the path so a later Save() with no arguments can reuse it
        $this.Path = $FilePath
        Set-Content -Path $FilePath -Value $this.ToString() -Encoding utf8 -NoNewline
    }

    # Save to the document's remembered path (set by Load or a prior Save)
    [void] Save() {
        if ([string]::IsNullOrEmpty($this.Path)) {
            throw "No path is set on this document; call Save(path) or load it from a file first."
        }
        $this.Save($this.Path)
    }

    # Set a key's value in a section, replacing any existing value(s).
    # The key adopts the document's current Delimiter as its original delimiter.
    [void] Set([string]$Section, [string]$Key, [string]$Value) {
        if ([string]::IsNullOrEmpty($Key)) {
            throw [System.ArgumentException]::new('Key cannot be null or empty.', 'Key')
        }
        $existing = @($this.Lines | Where-Object {
                $_.IsKeyValue() -and -not $_.IsDisabled -and $_.Section -eq $Section -and $_.Key -eq $Key
            })
        if ($existing.Count -gt 0) {
            $existing[0].Value = $Value
            $existing[0].Delimiter = $this.Delimiter
            for ($i = 1; $i -lt $existing.Count; $i++) {
                $this.Lines.Remove($existing[$i]) | Out-Null
            }
        }
        else {
            $this.AppendLine([IniKeyValueLine]::new($this, $Section, $Key, $Value, $this.Delimiter))
        }
        $this.RebuildSections()
    }

    # Set a top-level value (no section)
    [void] Set([string]$Key, [string]$Value) {
        $this.Set("", $Key, $Value)
    }

    # Set (or, with empty text, clear) the inline comment on a key/value line
    [void] SetInlineComment([string]$Section, [string]$Key, [string]$Text) {
        if ([string]::IsNullOrEmpty($Key)) {
            throw [System.ArgumentException]::new('Key cannot be null or empty.', 'Key')
        }
        if ([string]::IsNullOrEmpty($Text)) {
            $this.RemoveInlineComment($Section, $Key)
            return
        }
        foreach ($line in $this.Lines) {
            if ($line.IsKeyValue() -and $line.Section -eq $Section -and $line.Key -eq $Key) {
                $line.InlineComment = [IniComment]::Parse($Text)
                break
            }
        }
    }

    # Set a top-level (no-section) key's inline comment
    [void] SetInlineComment([string]$Key, [string]$Text) {
        $this.SetInlineComment("", $Key, $Text)
    }

    # Uncomment commented lines by exact, case-sensitive text.
    # A leading ";"/"#" marker in the input is ignored, so a whole comment line can be pasted in.
    [void] Uncomment([string]$Text) {
        if ([string]::IsNullOrEmpty($Text)) {
            throw [System.ArgumentException]::new('Text cannot be null or empty.', 'Text')
        }
        $key = [IniComment]::Parse($Text).MatchKey()
        $this.UncommentWhere({ param($line) $line -ceq $key }, $false, "")
    }

    # Uncomment matching commented lines only within a specific section
    [void] UncommentPattern([string]$Section, [string]$Pattern, [bool]$CaseSensitive) {
        if ([string]::IsNullOrEmpty($Pattern)) {
            throw [System.ArgumentException]::new('Pattern cannot be null or empty.', 'Pattern')
        }
        if ($CaseSensitive) {
            $this.UncommentWhere({ param($line) $line -cmatch $Pattern }, $true, $Section)
        }
        else {
            $this.UncommentWhere({ param($line) $line -imatch $Pattern }, $true, $Section)
        }
    }

    [void] UncommentPattern([string]$Section, [string]$Pattern) {
        $this.UncommentPattern($Section, $Pattern, $false)
    }

    # Uncomment commented lines whose text matches a regex pattern (case-insensitive by default).
    # Pass $true for $CaseSensitive to match case-sensitively (-cmatch)
    [void] UncommentPattern([string]$Pattern, [bool]$CaseSensitive) {
        if ([string]::IsNullOrEmpty($Pattern)) {
            throw [System.ArgumentException]::new('Pattern cannot be null or empty.', 'Pattern')
        }
        if ($CaseSensitive) {
            $this.UncommentWhere({ param($line) $line -cmatch $Pattern }, $false, "")
        }
        else {
            $this.UncommentWhere({ param($line) $line -imatch $Pattern }, $false, "")
        }
    }

    [void] UncommentPattern([string]$Pattern) {
        $this.UncommentPattern($Pattern, $false)
    }

    [string] ToString() {
        $output = [System.Collections.Generic.List[string]]::new()

        # Group lines by section, preserving first-appearance order
        $order = [System.Collections.Generic.List[string]]::new()
        $groups = @{}
        foreach ($line in $this.Lines) {
            if (-not $groups.ContainsKey($line.Section)) {
                $groups[$line.Section] = [System.Collections.Generic.List[AbstractIniLine]]::new()
                $order.Add($line.Section)
            }
            $groups[$line.Section].Add($line)
        }

        $sectionOrder = @($order)
        if ($this.SortSections) {
            # Keep top-level keys (empty section) first, then sort the named sections
            $sectionOrder = @($sectionOrder | Where-Object { $_ -eq "" }) +
                @($sectionOrder | Where-Object { $_ -ne "" } | Sort-Object)
        }

        foreach ($sectionName in $sectionOrder) {
            $sectionLines = $groups[$sectionName]

            if ($sectionName -ne "") {
                if ($output.Count -gt 0 -and $null -ne $this.SectionSpacing) {
                    # Normalize the gap before this section to exactly SectionSpacing blank lines
                    while ($output.Count -gt 0 -and $output[$output.Count - 1] -eq "") {
                        $output.RemoveAt($output.Count - 1)
                    }
                    for ($i = 0; $i -lt $this.SectionSpacing; $i++) {
                        $output.Add("")
                    }
                }
                # Prefer the stored header line so its inline comment is preserved
                $header = $sectionLines | Where-Object { $_.IsSection() } | Select-Object -First 1
                if ($null -ne $header) {
                    $output.Add($header.ToString())
                }
                else {
                    $output.Add("[$sectionName]")
                }
            }

            # Section headers are synthesized above, so drop stored header lines from the body
            $body = @($sectionLines | Where-Object { -not $_.IsSection() })
            if ($this.SortKeys) {
                # Alphabetize key/value lines into the slots they occupy; comments/blanks keep their positions
                $sortedKV = @($body | Where-Object { $_.IsKeyValue() -and -not $_.IsDisabled } | Sort-Object -Property Key)
                $next = 0
                $body = foreach ($line in $body) {
                    if ($line.IsKeyValue() -and -not $line.IsDisabled) {
                        $sortedKV[$next]
                        $next++
                    }
                    else {
                        $line
                    }
                }
            }

            foreach ($line in $body) {
                if ($this.StripComments -and ($line.IsCommentText() -or ($line.IsKeyValue() -and $line.IsDisabled))) {
                    continue
                }
                $output.Add($line.ToString())
            }
        }

        return ($output -join [System.Environment]::NewLine) + [System.Environment]::NewLine
    }
}
