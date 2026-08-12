class IniLine : AbstractIniLine {
    # Back-reference to the owning document, used for formatting during ToString()
    hidden [AbstractIniDocument] $Document
}
