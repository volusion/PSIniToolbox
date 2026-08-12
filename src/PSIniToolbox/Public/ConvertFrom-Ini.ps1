function ConvertFrom-Ini {
    <#
    .SYNOPSIS
        Parses INI-formatted text into an IniDocument.

    .DESCRIPTION
        Accepts INI content from the pipeline and returns an IniDocument. Both forms of
        Get-Content work: an array of lines (Get-Content ./app.ini) or a single multi-line
        string (Get-Content ./app.ini -Raw).

    .PARAMETER InputObject
        INI text, bound from the pipeline as either lines or a single string.

    .PARAMETER InlineCommentMode
        Whether to split trailing inline comments from values (None, First, or Last). Default None.

    .EXAMPLE
        Get-Content ./app.ini -Raw | ConvertFrom-Ini

    .EXAMPLE
        Get-Content ./app.ini | ConvertFrom-Ini

    .INPUTS
        System.String[]
        INI text piped in as an array of lines or a single raw multi-line string.

    .OUTPUTS
        IniDocument
        The parsed document, with sections, comments, and blank lines preserved.
    #>
    [CmdletBinding()]
    [OutputType([IniDocument])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string[]] $InputObject,

        [Parameter(Position = 0)]
        [IniInlineCommentMode] $InlineCommentMode = [IniInlineCommentMode]::None
    )

    begin {
        $lines = [System.Collections.Generic.List[string]]::new()
    }
    process {
        foreach ($item in $InputObject) {
            $parts = $item -split "\r?\n"
            # A -Raw string ends with a trailing newline, yielding an extra empty element; drop it.
            if ($parts.Count -gt 1 -and $parts[$parts.Count - 1] -eq "") {
                $parts = $parts[0..($parts.Count - 2)]
            }
            foreach ($part in $parts) {
                $lines.Add($part)
            }
        }
    }
    end {
        return [IniDocument]::Parse($lines.ToArray(), $InlineCommentMode)
    }
}
