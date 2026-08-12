#Requires -Version 5.1

# Dot-source classes first so their types are available to the public functions,
# then load the public functions and export them.
# Classes load in dependency order: the IniLine base must precede its subclasses,
# and every IniLine type must precede IniDocument (which references them).
$classLoadOrder = @(
    'IniDelimiterSpacing.ps1'
    'IniInlineCommentMode.ps1'
    'IniComment.ps1'
    'AbstractIniLine.ps1'
    'AbstractIniDocument.ps1'
    'IniLine.ps1'
    'IniBlankLine.ps1'
    'IniCommentLine.ps1'
    'IniSectionLine.ps1'
    'IniKeyValueLine.ps1'
    'IniDocument.ps1'
)
$classDir = Join-Path $PSScriptRoot 'Classes'
$orderedClasses = $classLoadOrder | ForEach-Object { Get-Item -Path (Join-Path $classDir $_) -ErrorAction SilentlyContinue }
$remainingClasses = Get-ChildItem -Path $classDir -Filter '*.ps1' -ErrorAction SilentlyContinue |
    Where-Object { $classLoadOrder -notcontains $_.Name }
$classFiles = @($orderedClasses) + @($remainingClasses) | Where-Object { $_ }
$publicFiles = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue)

foreach ($file in @($classFiles + $publicFiles)) {
    try {
        . $file.FullName
    }
    catch {
        throw "Failed to import '$($file.FullName)': $_"
    }
}

# Expose module classes as type accelerators so callers can use [IniDocument]
# without needing 'using module'.
$typeAccelerators = [psobject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
foreach ($type in @([IniDelimiterSpacing], [IniInlineCommentMode], [IniComment], [AbstractIniLine], [AbstractIniDocument], [IniLine], [IniBlankLine], [IniCommentLine], [IniSectionLine], [IniKeyValueLine], [IniDocument])) {
    if (-not $typeAccelerators::Get.ContainsKey($type.FullName)) {
        $typeAccelerators::Add($type.FullName, $type)
    }
}

# Remove the accelerators again when the module is unloaded.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    $ta = [psobject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
    foreach ($type in @([IniDelimiterSpacing], [IniInlineCommentMode], [IniComment], [AbstractIniLine], [AbstractIniDocument], [IniLine], [IniBlankLine], [IniCommentLine], [IniSectionLine], [IniKeyValueLine], [IniDocument])) {
        $ta::Remove($type.FullName) | Out-Null
    }
}.GetNewClosure()

Export-ModuleMember -Function $publicFiles.BaseName
