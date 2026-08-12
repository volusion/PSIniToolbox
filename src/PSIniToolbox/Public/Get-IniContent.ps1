function Get-IniContent {
    <#
    .SYNOPSIS
        Reads an INI file and returns an IniDocument that preserves comments and layout.

    .DESCRIPTION
        Parses an INI-formatted configuration file into an IniDocument object. Sections,
        key/value pairs, comments, and blank lines are retained so the document can be
        modified and written back out with its original structure intact. Repeated keys
        within a section are collected into an array of values.

    .PARAMETER Path
        Path to the INI file to read.

    .PARAMETER InlineCommentMode
        Whether to split trailing inline comments from values (None, First, or Last). Default None.

    .EXAMPLE
        $ini = Get-IniContent -Path ./app.ini
        $ini.Set('database', 'host', 'localhost')
        Save-IniContent -Document $ini -Path ./app.ini

    .INPUTS
        System.String
        A path to an INI file, bound from the pipeline by value or by property name.

    .OUTPUTS
        IniDocument
        The parsed document, with sections, comments, and blank lines preserved.
    #>
    [CmdletBinding()]
    [OutputType([IniDocument])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FilePath', 'FullName')]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Position = 1)]
        [IniInlineCommentMode] $InlineCommentMode = [IniInlineCommentMode]::None
    )

    process {
        $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
        return [IniDocument]::Load($resolved.ProviderPath, $InlineCommentMode)
    }
}
