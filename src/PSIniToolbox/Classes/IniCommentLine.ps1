class IniCommentLine : IniLine {
    # The comment's symbol and marker-free content
    [IniComment] $Comment

    IniCommentLine([AbstractIniDocument]$Document, [string]$Section, [string]$CommentSymbol, [string]$Content) {
        $this.Document = $Document
        $this.Kind = "Comment"
        $this.Section = $Section
        $this.Comment = [IniComment]::new($CommentSymbol, $Content)
    }

    IniCommentLine([AbstractIniDocument]$Document, [string]$Section, [string]$CommentSymbol, [string]$Content, [int]$SpaceCount) {
        $this.Document = $Document
        $this.Kind = "Comment"
        $this.Section = $Section
        $this.Comment = [IniComment]::new($CommentSymbol, $Content, $SpaceCount)
    }

    [bool] IsCommentText() { return $true }

    [string] ToString() {
        return $this.Comment.Render($this.Document.PreserveCommentSymbols, $this.Document.CommentSymbol, $this.Document.PreserveCommentSpacing)
    }
}
