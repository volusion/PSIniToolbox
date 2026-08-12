class IniSectionLine : IniLine {
    # Optional trailing inline comment
    [IniComment] $InlineComment

    IniSectionLine([AbstractIniDocument]$Document, [string]$Name) {
        $this.Document = $Document
        $this.Kind = "Section"
        $this.Section = $Name
    }

    [bool] IsSection() { return $true }

    [string] ToString() {
        $text = "[$($this.Section)]"
        if ($null -ne $this.InlineComment -and -not $this.Document.StripComments) {
            $text = "$text  " + $this.InlineComment.Render($this.Document.PreserveCommentSymbols, $this.Document.CommentSymbol, $this.Document.PreserveCommentSpacing)
        }
        return $text
    }
}
