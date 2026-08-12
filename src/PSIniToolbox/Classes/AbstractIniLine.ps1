# This is a simulated Abstract class, specifically for resolving cylical references at module import time.
class AbstractIniLine {
    # 'Blank', 'Comment', 'Section', or 'KeyValue'
    [string] $Kind

    # Owning section ("" for top-level); for Section lines, the declared name
    [string] $Section = ""

    [bool] IsBlank() { return $false }
    [bool] IsSection() { return $false }
    [bool] IsKeyValue() { return $false }
    [bool] IsCommentText() { return $false }

    [string] ToString() {
        throw [System.NotImplementedException]::new()
    }
}
