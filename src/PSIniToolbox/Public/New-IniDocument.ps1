function New-IniDocument {
    <#
    .SYNOPSIS
        Creates a new, empty IniDocument.

    .DESCRIPTION
        Returns a fresh IniDocument that can be populated with the Add/Set methods and
        written to disk with Save-IniContent.

    .EXAMPLE
        $ini = New-IniDocument
        $ini.Set('server', 'port', '8080')
        Save-IniContent -Document $ini -Path ./app.ini

    .INPUTS
        None. This command does not accept pipeline input.

    .OUTPUTS
        IniDocument
        A new, empty document ready to populate with the Add/Set methods.
    #>
    [CmdletBinding()]
    [OutputType([IniDocument])]
    param()

    return [IniDocument]::new()
}
