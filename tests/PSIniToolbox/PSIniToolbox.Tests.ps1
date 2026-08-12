BeforeAll {
    # Resolve the module manifest relative to the repo root (walk up to 'tests', then to sibling 'src').
    $testsRoot = $PSScriptRoot
    while ((Split-Path $testsRoot -Leaf) -ne 'tests') { $testsRoot = Split-Path $testsRoot -Parent }
    Import-Module (Join-Path (Split-Path $testsRoot -Parent) 'src/PSIniToolbox/PSIniToolbox.psd1') -Force
}

Describe 'PSIniToolbox module' {
    It 'exports the expected public functions' {
        $exported = (Get-Command -Module 'PSIniToolbox').Name | Sort-Object
        $exported | Should -Be @('ConvertFrom-Ini', 'ConvertTo-Ini', 'Get-IniContent', 'New-IniDocument', 'Save-IniContent')
    }

    It 'registers the module classes as type accelerators' {
        (New-IniDocument) | Should -BeOfType ([IniDocument])
        [IniDelimiterSpacing]::Spaces | Should -Be ([IniDelimiterSpacing]::Spaces)
    }

    It 'throws a helpful error when a class file fails to load' {
        $moduleBase = (Get-Module 'PSIniToolbox').ModuleBase
        $manifest = Join-Path $moduleBase 'PSIniToolbox.psd1'
        $brokenFile = Join-Path (Join-Path $moduleBase 'Classes') 'zzzz-coverage-break.ps1'
        try {
            Set-Content -Path $brokenFile -Value "throw 'intentional coverage failure'" -Encoding utf8
            { Import-Module $manifest -Force -ErrorAction Stop } |
                Should -Throw -ExpectedMessage '*Failed to import*zzzz-coverage-break*'
        }
        finally {
            Remove-Item -Path $brokenFile -Force -ErrorAction SilentlyContinue
            # Restore a clean module so the type accelerators are re-registered for later tests
            Import-Module $manifest -Force
        }
    }
}
