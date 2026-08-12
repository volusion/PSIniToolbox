class IniKeyValueLine : IniLine {
    [string] $Key
    [string] $Value
    [string] $Delimiter = "="

    # Per-line spacing around the delimiter, detected on parse; used when the document preserves delimiter spacing
    [IniDelimiterSpacing] $DelimiterSpacing = [IniDelimiterSpacing]::Spaces

    # When true the setting is rendered commented out
    [bool] $IsDisabled = $false

    # Optional trailing inline comment
    [IniComment] $InlineComment

    IniKeyValueLine([AbstractIniDocument]$Document, [string]$Section, [string]$Key, [string]$Value, [string]$Delimiter) {
        $this.Document = $Document
        $this.Kind = "KeyValue"
        $this.Section = $Section
        $this.Key = $Key
        $this.Value = $Value
        $this.Delimiter = $Delimiter
    }

    # Classify delimiter spacing from the number of spaces on each side of the delimiter
    static [IniDelimiterSpacing] DetectSpacing([int]$Before, [int]$After) {
        if ($Before -gt 1) { return [IniDelimiterSpacing]::Align }
        if ($Before -eq 1 -and $After -ge 1) { return [IniDelimiterSpacing]::Spaces }
        if ($Before -eq 1) { return [IniDelimiterSpacing]::SpaceLeft }
        if ($After -ge 1) { return [IniDelimiterSpacing]::SpaceRight }
        return [IniDelimiterSpacing]::None
    }

    [bool] IsKeyValue() { return $true }

    [string] ToString() {
        $delim = if ($this.Document.PreserveDelimiters) { $this.Delimiter } else { $this.Document.Delimiter }
        $spacing = if ($this.Document.PreserveDelimiterSpacing) { $this.DelimiterSpacing } else { $this.Document.DelimiterSpacing }

        $text = ""
        switch ($spacing) {
            ([IniDelimiterSpacing]::Align) {
                # Pad the key to the widest key in this section (cached on the document)
                $width = 0
                if ($this.Document.KeyWidths.ContainsKey($this.Section)) {
                    $width = $this.Document.KeyWidths[$this.Section]
                }
                $text = "$($this.Key.PadRight($width)) $delim $($this.Value)"
            }
            ([IniDelimiterSpacing]::Spaces) {
                $text = "$($this.Key) $delim $($this.Value)"
            }
            ([IniDelimiterSpacing]::SpaceLeft) {
                $text = "$($this.Key) $delim$($this.Value)"
            }
            ([IniDelimiterSpacing]::SpaceRight) {
                $text = "$($this.Key)$delim $($this.Value)"
            }
            default {
                $text = "$($this.Key)$delim$($this.Value)"
            }
        }

        if ($null -ne $this.InlineComment -and -not $this.Document.StripComments) {
            $text = "$text  " + $this.InlineComment.Render($this.Document.PreserveCommentSymbols, $this.Document.CommentSymbol, $this.Document.PreserveCommentSpacing)
        }

        if ($this.IsDisabled) { return "$($this.Document.CommentSymbol) $text" }
        return $text
    }
}
