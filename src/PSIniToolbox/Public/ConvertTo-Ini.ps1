function ConvertTo-Ini {
    <#
    .SYNOPSIS
        Serializes an IniDocument to INI-formatted text.

    .DESCRIPTION
        Returns the INI text for an IniDocument, applying its formatting options. The
        output ends with a trailing newline, matching what Save-IniContent writes.

    .PARAMETER Document
        The IniDocument to serialize. Accepts pipeline input.

    .EXAMPLE
        $ini | ConvertTo-Ini

    .EXAMPLE
        Get-Content ./app.ini -Raw | ConvertFrom-Ini | ConvertTo-Ini

    .INPUTS
        IniDocument
        The document to serialize, bound from the pipeline.

    .OUTPUTS
        System.String
        The INI text for the document, ending with a trailing newline.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [IniDocument] $Document
    )

    process {
        return $Document.ToString()
    }
}
