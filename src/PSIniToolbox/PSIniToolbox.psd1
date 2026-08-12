@{
    RootModule        = 'PSIniToolbox.psm1'
    ModuleVersion     = '1.0.0' # x-release-please-version
    GUID              = 'ee6e5d66-34f8-4960-9a50-ededcb36b03c'
    Author            = 'Ian Cervantez'
    CompanyName       = 'Volusion'
    Copyright         = '(c) Volusion. All rights reserved.'
    Description       = 'Helpers to parse, edit, and write INI configuration files while preserving comments, blank lines, and layout.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @('ConvertFrom-Ini', 'ConvertTo-Ini', 'Get-IniContent', 'New-IniDocument', 'Save-IniContent')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('ini', 'config', 'configuration', 'parser', 'settings', 'PSEdition_Core', 'PSEdition_Desktop', 'Windows', 'Linux', 'MacOS')
            LicenseUri   = 'https://github.com/volusion/PSIniToolbox/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/volusion/PSIniToolbox'
            ReleaseNotes = 'Initial release: Get-IniContent, New-IniDocument, and Save-IniContent with comment/layout-preserving IniDocument.'
        }
    }
}
