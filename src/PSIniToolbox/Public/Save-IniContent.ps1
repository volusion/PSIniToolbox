function Save-IniContent {
    <#
    .SYNOPSIS
        Writes an IniDocument to a file.

    .DESCRIPTION
        Serializes an IniDocument back to INI format, preserving comments, blank lines,
        and the detected spacing style, then writes it to the specified path.

    .PARAMETER Document
        The IniDocument to write.

    .PARAMETER Path
        Destination path for the INI file. Defaults to the path the document was loaded
        from (or last saved to).

    .EXAMPLE
        Save-IniContent -Document $ini -Path ./app.ini

    .EXAMPLE
        $ini | Save-IniContent -Path ./app.ini

    .EXAMPLE
        Get-IniContent ./app.ini | Save-IniContent   # writes back to ./app.ini

    .INPUTS
        IniDocument
        The document to write, bound from the pipeline.

    .OUTPUTS
        None. This command writes the document to disk and returns nothing.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ValidateNotNull()]
        [IniDocument] $Document,

        [Parameter(Position = 1)]
        [Alias('FilePath')]
        [string] $Path
    )

    process {
        $target = if ([string]::IsNullOrEmpty($Path)) { $Document.Path } else { $Path }
        if ([string]::IsNullOrEmpty($target)) {
            throw "No -Path was provided and the document has no saved path (it was not loaded from a file)."
        }
        if ($PSCmdlet.ShouldProcess($target, 'Write INI content')) {
            $Document.Save($target)
        }
    }
}
