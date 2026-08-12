class IniBlankLine : IniLine {
    IniBlankLine([AbstractIniDocument]$Document, [string]$Section) {
        $this.Document = $Document
        $this.Kind = "Blank"
        $this.Section = $Section
    }

    [bool] IsBlank() { return $true }

    [string] ToString() {
        return ""
    }
}
