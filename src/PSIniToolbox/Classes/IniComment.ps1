class IniComment {
    # Comment marker: ";" or "#"
    [string] $CommentSymbol = ";"

    # The comment text without the leading marker
    [string] $Content = ""

    # Number of spaces between the marker and the content as seen when parsed
    [int] $SpaceCount = 1

    IniComment() {}

    IniComment([string]$CommentSymbol, [string]$Content) {
        $this.CommentSymbol = $CommentSymbol
        $this.Content = $Content
    }

    IniComment([string]$CommentSymbol, [string]$Content, [int]$SpaceCount) {
        $this.CommentSymbol = $CommentSymbol
        $this.Content = $Content
        $this.SpaceCount = $SpaceCount
    }

    # Split "; text" (or "# text") into its symbol, space count, and marker-free content
    static [IniComment] Parse([string]$Text) {
        if ($Text -match "^\s*([;#])( *)(.*)$") {
            return [IniComment]::new($matches[1], $matches[3], $matches[2].Length)
        }
        return [IniComment]::new(";", $Text)
    }

    # Render to "symbol content", honoring the document's symbol- and spacing-preservation settings
    [string] Render([bool]$PreserveCommentSymbol, [string]$DefaultCommentSymbol, [bool]$PreserveCommentSpacing) {
        $symbol = if ($PreserveCommentSymbol) { $this.CommentSymbol } else { $DefaultCommentSymbol }
        if ($this.Content -eq "") { return $symbol }
        if ($PreserveCommentSpacing) {
            return "$symbol$(' ' * $this.SpaceCount)$($this.Content)"
        }
        # Decorative divider lines (e.g. ";;;;;") render with no space after the marker
        if ($this.Content -match "^[;#]+$") { return "$symbol$($this.Content)" }
        return "$symbol $($this.Content)"
    }

    # Key used for exact comment matching: marker-free content with only the single separating
    # space after the marker removed, so "; x" and "x" match but ";   x" (an indented example) does not
    [string] MatchKey() {
        if ($this.SpaceCount -le 1) { return $this.Content }
        return (' ' * ($this.SpaceCount - 1)) + $this.Content
    }
}
