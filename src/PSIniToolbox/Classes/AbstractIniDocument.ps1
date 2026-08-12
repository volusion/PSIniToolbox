# This is a simulated Abstract class, specifically for resolving cylical references at module import time.
class AbstractIniDocument {
    # Ordered, line-by-line representation that is the source of truth for layout
    [System.Collections.Generic.List[AbstractIniLine]] $Lines

    # Read projection: section -> key -> value(s); rebuilt after each mutation
    [System.Collections.Specialized.OrderedDictionary] $Sections

    # Cache of the widest key length per section, used for Align spacing; rebuilt with Sections
    hidden [System.Collections.Generic.Dictionary[string, int]] $KeyWidths

    # Formatting options controlling how the document is written out
    [IniDelimiterSpacing] $DelimiterSpacing = [IniDelimiterSpacing]::Spaces

    # Delimiter written between keys and values ("=" or ":")
    [string] $Delimiter = "="

    # When true, named sections are written in alphabetical order (keys within each section keep their order)
    [bool] $SortSections = $false

    # When true, key/value entries within a section are written in alphabetical order (comments and blank lines stay put)
    [bool] $SortKeys = $false

    # When true, all comments are omitted from the output
    [bool] $StripComments = $false

    # Number of blank lines written between sections; $null preserves existing blank lines as-is
    [System.Nullable[int]] $SectionSpacing = 1

    # When true, each property keeps its original delimiter; when false, Delimiter is used for all
    [bool] $PreserveDelimiters = $false

    # When true, each key/value line keeps its own delimiter spacing; when false, DelimiterSpacing is used for all
    [bool] $PreserveDelimiterSpacing = $false

    # Comment marker written before comments (";" or "#")
    [string] $CommentSymbol = ";"

    # When true, each comment keeps its original symbol; when false, CommentSymbol is used for all
    [bool] $PreserveCommentSymbols = $false

    # When true, each comment keeps the number of spaces after its marker; when false, a single space is used
    [bool] $PreserveCommentSpacing = $false

    # How inline comments are detected while parsing values (None, First, or Last)
    [IniInlineCommentMode] $InlineCommentMode = [IniInlineCommentMode]::None

    # Path this document was loaded from or last saved to; used by Save() with no arguments
    [string] $Path = ""

    # Abstract contract: IniDocument provides the real implementations.
    [object] Get([string]$Key) { throw [System.NotImplementedException]::new() }
    [object] Get([string]$Section, [string]$Key) { throw [System.NotImplementedException]::new() }
    [void] Add([string]$Key, [string]$Value) { throw [System.NotImplementedException]::new() }
    [void] Add([string]$Section, [string]$Key, [string]$Value) { throw [System.NotImplementedException]::new() }
    [void] Add([string]$Section, [string]$Key, [string]$Value, [string]$LineDelimiter) { throw [System.NotImplementedException]::new() }
    [void] Set([string]$Key, [string]$Value) { throw [System.NotImplementedException]::new() }
    [void] Set([string]$Section, [string]$Key, [string]$Value) { throw [System.NotImplementedException]::new() }
    [void] Remove([string]$Key) { throw [System.NotImplementedException]::new() }
    [void] Remove([string]$Section, [string]$Key) { throw [System.NotImplementedException]::new() }
    [void] AddComment([string]$Text) { throw [System.NotImplementedException]::new() }
    [void] AddComment([string]$Section, [string]$Text) { throw [System.NotImplementedException]::new() }
    [void] AddSection([string]$Section) { throw [System.NotImplementedException]::new() }
    [void] RemoveSection([string]$Section) { throw [System.NotImplementedException]::new() }
    [void] Uncomment([string]$Text) { throw [System.NotImplementedException]::new() }
    [void] UncommentPattern([string]$Pattern) { throw [System.NotImplementedException]::new() }
    [void] UncommentPattern([string]$Pattern, [bool]$CaseSensitive) { throw [System.NotImplementedException]::new() }
    [void] UncommentPattern([string]$Section, [string]$Pattern) { throw [System.NotImplementedException]::new() }
    [void] UncommentPattern([string]$Section, [string]$Pattern, [bool]$CaseSensitive) { throw [System.NotImplementedException]::new() }
    [void] Comment([string]$Text) { throw [System.NotImplementedException]::new() }
    [void] CommentPattern([string]$Pattern) { throw [System.NotImplementedException]::new() }
    [void] CommentPattern([string]$Pattern, [bool]$CaseSensitive) { throw [System.NotImplementedException]::new() }
    [void] CommentPattern([string]$Section, [string]$Pattern) { throw [System.NotImplementedException]::new() }
    [void] CommentPattern([string]$Section, [string]$Pattern, [bool]$CaseSensitive) { throw [System.NotImplementedException]::new() }
    [void] ReplaceComment([string]$OldText, [string]$NewText) { throw [System.NotImplementedException]::new() }
    [void] SetInlineComment([string]$Key, [string]$Text) { throw [System.NotImplementedException]::new() }
    [void] SetInlineComment([string]$Section, [string]$Key, [string]$Text) { throw [System.NotImplementedException]::new() }
    [void] RemoveInlineComment([string]$Key) { throw [System.NotImplementedException]::new() }
    [void] RemoveInlineComment([string]$Section, [string]$Key) { throw [System.NotImplementedException]::new() }
    [void] Save() { throw [System.NotImplementedException]::new() }
    [void] Save([string]$FilePath) { throw [System.NotImplementedException]::new() }
    [string] ToString() { throw [System.NotImplementedException]::new() }
}
