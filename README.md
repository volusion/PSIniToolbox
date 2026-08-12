# PSIniToolbox

An over-engineered PowerShell module with helpers to parse, edit, and write INI configuration files. Comments, blank 
lines, key ordering, and the file's spacing style are preserved through a load / edit / save round trip.

## Installation

```powershell
Install-Module -Name PSIniToolbox -Scope CurrentUser
Import-Module PSIniToolbox
```

## Concepts

- **`IniDocument`** is the object you work with. It keeps the file as an ordered list of lines (`$ini.Lines`) so
  comments, blank lines, and layout survive a round trip.
- **`$ini.Sections`** is a convenient read projection: `section -> key -> value`. Top-level keys (before any
  `[section]`) live under the empty-string section `''`. Repeated keys become an array. Treat it as read-only;
  use the methods below to change the document.
- Formatting is controlled by properties on the document (delimiter, spacing, sorting, comment symbol, …) and
  applied when you serialize with `ConvertTo-Ini` / `Save-IniContent`.

---

## Cmdlets

### Get-IniContent
Reads an INI file into an `IniDocument`.

Usage:

`Get-IniContent -Path <file> [-InlineCommentMode <None|First|Last>]`

```powershell
# app.ini:
#   [database]
#   host = localhost
#   port = 5432

$ini = Get-IniContent -Path ./app.ini
$ini.Sections['database']['host'] # => localhost
$ini.Sections['database']['port'] # => 5432
```

### ConvertFrom-Ini
Parses INI text from the pipeline into an `IniDocument`. Works with both `Get-Content` (an array of lines) and
`Get-Content -Raw` (a single string).

Usage:

`ConvertFrom-Ini [-InlineCommentMode <None|First|Last>]`

```powershell
$ini = Get-Content ./app.ini -Raw | ConvertFrom-Ini
# or
$ini = Get-Content ./app.ini | ConvertFrom-Ini
# or from a literal string
$ini = "[database]`nhost = localhost" | ConvertFrom-Ini
```

### ConvertTo-Ini
Serializes an `IniDocument` back to INI text. The string ends with a trailing newline.

Usage:

`ConvertTo-Ini`

```powershell
$ini | ConvertTo-Ini
# [database]
# host = localhost
```

### New-IniDocument
Creates a new, empty `IniDocument` to build from scratch.

Usage:

`New-IniDocument`

```powershell
$ini = New-IniDocument
$ini.Set('server', 'port', '8080')
$ini | ConvertTo-Ini
# [server]
# port = 8080
```

### Save-IniContent
Writes an `IniDocument` to a file. `-Path` is optional; when omitted it writes back to the path the document was
loaded from (or last saved to).

Usage:

`Save-IniContent -Document <IniDocument> [-Path <file>]`

```powershell
$ini = Get-IniContent ./app.ini
$ini.Set('database', 'host', '127.0.0.1')

# save changes to the original file
$ini | Save-IniContent

# save changes to a different file
$ini | Save-IniContent -Path ./copy.ini
```

---

## Accessing values

```powershell
$ini = @'
appName = My App

[database]
host = localhost
'@ | ConvertFrom-Ini

# Access the value of a top level key
$ini.Get('appName')
# => My App

# Access the value of a key within a section
$ini.Get('database', 'host')
# => localhost

# Alternatively, you can access values through the Sections property

# Top-level keys (before any [section]) live under the empty-string section ''
$ini.Sections['']['appName']
# => My App

# Keys in a section live under that section's name
$ini.Sections['database']['host']
# => localhost
```

## Editing values

### Setting a key's value

```powershell
$ini = @'
appName = My App

[database]
host = localhost
'@ | ConvertFrom-Ini

# Set a "top level" key/value (that doesn't exist in a section)
$ini.Set('appName', 'Demo')

# Change the "localhost" to "127.0.0.1"
$ini.Set('database', 'host', '127.0.0.1')

$ini | ConvertTo-Ini
# appName = Demo
#
# [database]
# host = 127.0.0.1
```

### Adding keys/values

```powershell
$ini = @'
[database]
'@ | ConvertFrom-Ini

# Add a key/value to a section
$ini.Add('database', 'server', 'node-1')

$ini.Sections['database']['server']  # 'node-1'

$ini | ConvertTo-Ini
# [database]
# server = node-1

# Add more of the same key (array style)
$ini.Add('database', 'server', 'node-2')

$ini.Sections['database']['server']  # => @('node-1', 'node-2')

$ini | ConvertTo-Ini
# [database]
# server = node-1
# server = node-2
```

### Removing keys

```powershell
$ini = @'
appName = My App

[database]
host = localhost
port = 5432
'@ | ConvertFrom-Ini

# Remove a top level key/value
$ini.Remove('appName')

# Remove a key/value from a section
$ini.Remove('database', 'port')

$ini | ConvertTo-Ini
# [database]
# host = localhost
```

---

## Sections

### Add a section

```powershell
$ini = @'
[database]
host = localhost
'@ | ConvertFrom-Ini

$ini.AddSection('web')

$ini | ConvertTo-Ini
# [database]
# host = localhost
#
# [web]
```

### Remove a section

```powershell
$ini = @'
[web]
host = 127.0.0.1
port = 8080

[database]
server = localhost
port = 5432
'@ | ConvertFrom-Ini

$ini.RemoveSection('web')

$ini | ConvertTo-Ini
# [database]
# server = localhost
# port = 5432
```

> ⓘ **Note:**<br/>
> Adding a section that already exists, or removing a non-existent section result in no-ops.

---

## Comments

### Adding Comments

Appends a comment line. A leading `;`/`#` is used as the symbol; otherwise the document's
`CommentSymbol` is applied.

```powershell
$ini = @'
[database]
host = localhost
'@ | ConvertFrom-Ini

# Add a "global" comment
$ini.AddComment('App Config File')

# Add a comment to a section
$ini.AddComment('database', 'replace localhost above with your actual host')

# Adding a comment with a comment symbol at the beginning is gracefully supported
$ini.AddComment('database', '; port optional')

$ini | ConvertTo-Ini
# ; App Config File
#
# [database]
# host = localhost
# ; replace localhost above with your actual host
# ; port optional
```

### Commenting Lines

Comments out a key/value or section line, matching it **as it renders** — the same text `ConvertTo-Ini` would
write (honoring `Delimiter`, `DelimiterSpacing`, and any inline comment). `Comment` matches the exact,
case-sensitive line; `CommentPattern` matches a regex.

```powershell
$ini = @'
[web]
host = 127.0.0.1
port = 8080

[database]
server = localhost
port = 5432
'@ | ConvertFrom-Ini

# Comment a line by its exact, rendered text
$ini.Comment('server = localhost')

# Comment matching lines with a regex
$ini.CommentPattern('^port\s*=')

$ini | ConvertTo-Ini
# [web]
# host = 127.0.0.1
# ; port = 8080
# 
# [database]
# ; server = localhost
# ; port = 5432
```

Notice: the pattern matched the same key in multiple sections, so it commented both lines.
With great power comes great responsibility...  Unanchored pattern matches can wreak havoc.
As with all things RegEx, only use it if you have to.

```powershell
$ini = @'
[web]
host = 127.0.0.1
port = 8080

[database]
server = localhost
port = 5432
'@ | ConvertFrom-Ini

# Unanchored comment patterns can match both key and value text
$ini.CommentPattern('host')

$ini | ConvertTo-Ini
# [web]
# ; host = 127.0.0.1
# port = 8080
# 
# [database]
# ; server = localhost
# port = 5432
```

You can narrow the scope your CommentPattern calls to specific sections or opt in for case-sensitive matches.

```powershell
$ini.CommentPattern('host')                     # all sections, case-insensitive (default)
$ini.CommentPattern('host', $true)              # all sections, case-sensitive
$ini.CommentPattern('database', 'host')         # only [database] section, case-insensitive
$ini.CommentPattern('database', 'host', $true)  # only [database] section, case-sensitive
```

> ⓘ **Note:**<br/>
> Commenting a section header re-scopes its following lines back into the previous (enclosing) section.

### Uncommenting Lines

The inverse: enables a commented line. `Uncomment` matches the exact comment content (gracefully handling leading 
comment symbols in the input text). `UncommentPattern` matches a regex and takes the same optional section-scope and
case-sensitivity arguments as `CommentPattern`.

```powershell
$ini = @'
[web]
host = 127.0.0.1
; port = 8080

[database]
; server = localhost
; port = 5432
; database = postgres
'@ | ConvertFrom-Ini

# Uncomment a line by its exact content
$ini.Uncomment('server = localhost')

# Uncomment a line by its exact content, gracefully handling comment symbols
$ini.Uncomment('; database = postgres')

# Uncomment matching lines with a regex
$ini.UncommentPattern('^port\s*=')

$ini | ConvertTo-Ini
# [web]
# host = 127.0.0.1
# port = 8080
# 
# [database]
# server = localhost
# port = 5432
# database = postgres
```

Notice: the pattern matched the same key in multiple sections, so it uncommented both lines.
With great power comes great responsibility...  Unanchored pattern matches can wreak havoc.
As with all things RegEx, only use it if you have to.

```powershell
$ini = @'
[web]
; host = 127.0.0.1
port = 8080

[database]
; server = localhost
port = 5432
'@ | ConvertFrom-Ini

# Unanchored uncomment patterns can match both key and value text
$ini.UncommentPattern('host')

$ini | ConvertTo-Ini
# [web]
# host = 127.0.0.1
# port = 8080
# 
# [database]
# server = localhost
# port = 5432
```

You can narrow the scope your UncommentPattern calls to specific sections or opt in for case-sensitive matches.

```powershell
$ini.UncommentPattern('host')                     # all sections, case-insensitive (default)
$ini.UncommentPattern('host', $true)              # all sections, case-sensitive
$ini.UncommentPattern('database', 'host')         # only [database] section, case-insensitive
$ini.UncommentPattern('database', 'host', $true)  # only [database] section, case-sensitive
```

> ⓘ **Note:**<br/>
> Uncommenting a commented section header (e.g. `; [advanced]`) turns it into a real section and re-scopes the
> following lines into it.

### Replacing Comment Text

Replaces a comment's text (case-sensitive match on the content after the marker).

```powershell
$ini = @'
; old note

[database]
; replace "localhost"
host = localhost
'@ | ConvertFrom-Ini

# Replace a comment
$ini.ReplaceComment('old note', 'new note')

# Replace a comment, gracefully handling comment symbols
$ini.ReplaceComment('; replace "localhost"', '; update "localhost"')

$ini | ConvertTo-Ini
# ; new note
#
# [database]
# ; update "localhost"
# host = localhost
```

---

## Inline comments

Off by default. Enable parsing with `-InlineCommentMode First|Last`, which splits a value at the first/last
occurrence of the document's comment symbol. The value in `Sections` is the clean text; the comment is kept on
the line and re-emitted.

```powershell
$ini = "host = localhost ; primary" | ConvertFrom-Ini -InlineCommentMode First

$ini.Sections['']['host'] # => localhost   (comment stripped from the value)

$ini | ConvertTo-Ini
# host = localhost ; primary
```

### Setting Inline Comment Text

```powershell
$ini = @'
[database]
host = localhost
port = 5432
'@ | ConvertFrom-Ini

# Add an inline comment
$ini.SetInlineComment('database', 'host', 'replace with your host')

# Add an inline comment, gracefully handle the comment symbol
$ini.SetInlineComment('database', 'port', '; default port is optional')

$ini | ConvertTo-Ini
# [database]
# host = localhost ; replace with your host
# port = 5432 ; default port is optional

# Remove an inline comment
$ini.RemoveInlineComment('database', 'port')

$ini | ConvertTo-Ini
# [database]
# host = localhost ; replace with your host
# port = 5432
```

---

## Saving

`Save()` writes to the document's original `Path` (at the time of `Get-IniContent`/`Load` or a prior `Save`).
`Save(path)` writes to a specific file.

```powershell
$ini = Get-IniContent ./app.ini
$ini.Set('database', 'host', '127.0.0.1')

# Write $ini to the original ./app.ini
$ini.Save()

# Write $ini to a different file than was initially loaded
$ini.Save('./copy.ini')
```

---

## Formatting options

Set these properties on the document; they take effect on the next serialize.

| Property                   | Type                                                                         | Default             | Effect                                                                                                                    |
|----------------------------|------------------------------------------------------------------------------|---------------------|---------------------------------------------------------------------------------------------------------------------------|
| `DelimiterSpacing`         | `IniDelimiterSpacing` (`None`, `Spaces`, `SpaceLeft`, `SpaceRight`, `Align`) | `Spaces`            | `None` = `k=v`, `Spaces` = `k = v`, `SpaceLeft` = `k =v`, `SpaceRight` = `k= v`, `Align` = pad keys so delimiters line up |
| `Delimiter`                | `string`                                                                     | `=`                 | Character between key and value (typically `=` or `:`), auto-detected on load                                             |
| `PreserveDelimiters`       | `bool`                                                                       | `$false`            | Keep each line's original `:`/`=` instead of using `Delimiter`                                                            |
| `PreserveDelimiterSpacing` | `bool`                                                                       | `$false` / `$true`* | Keep each line's own spacing around the delimiter instead of using `DelimiterSpacing`                                     |
| `CommentSymbol`            | `string`                                                                     | `;`                 | Comment marker used on write (typically `;` or `#`), auto-detected on load                                                |
| `PreserveCommentSymbols`   | `bool`                                                                       | `$false`            | Keep each comment's original `;`/`#`                                                                                      |
| `PreserveCommentSpacing`   | `bool`                                                                       | `$false` / `$true`* | Keep each comment's original spaces after the marker instead of a single space                                            |
| `SortSections`             | `bool`                                                                       | `$false`            | Write named sections alphabetically (top-level keys stay first)                                                           |
| `SortKeys`                 | `bool`                                                                       | `$false`            | Write keys alphabetically within each section                                                                             |
| `StripComments`            | `bool`                                                                       | `$false`            | Omit all comments (including inline) from the output                                                                      |
| `SectionSpacing`           | `[int]?`                                                                     | `1`                 | Blank lines between sections; `$null` preserves existing gaps                                                             |
| `InlineCommentMode`        | `IniInlineCommentMode` (`None`, `First`, `Last`)                             | `None`              | Inline-comment parsing: `None` keeps values verbatim, `First`/`Last` split at the first/last comment symbol in a value    |
| `Sections`                 | `OrderedDictionary`                                                          | —                   | Read projection `section -> key -> value(s)`                                                                              |
| `Path`                     | `string`                                                                     | `''`                | File the document is bound to; used by `Save()`                                                                           |

\* `PreserveDelimiterSpacing` and `PreserveCommentSpacing` default to `$false` for a document created with `New-IniDocument`, and to `$true` for one parsed from existing content (`Get-IniContent`, `ConvertFrom-Ini`), so loaded files keep their original spacing while newly built ones are normalized.

### `DelimiterSpacing`

```powershell
$ini = @'
[db]
host = localhost
longerkey = 5432
'@ | ConvertFrom-Ini

$ini.DelimiterSpacing = [IniDelimiterSpacing]::Align
$ini | ConvertTo-Ini
# [db]
# host      = localhost
# longerkey = 5432

$ini.DelimiterSpacing = [IniDelimiterSpacing]::None
$ini | ConvertTo-Ini
# [db]
# host=localhost
# longerkey=5432
```

### `Delimiter`

```powershell
$ini = "host = localhost" | ConvertFrom-Ini
$ini.Delimiter = ':'
$ini | ConvertTo-Ini
# host : localhost
```

### `PreserveDelimiters`

```powershell
$ini = @'
host = localhost
port : 5432
'@ | ConvertFrom-Ini

$ini.PreserveDelimiters = $true
$ini | ConvertTo-Ini
# host = localhost
# port : 5432

$ini.PreserveDelimiters = $false     # normalize all to Delimiter
$ini | ConvertTo-Ini
# host = localhost
# port = 5432
```

### `PreserveDelimiterSpacing`

Each line's spacing is classified on load: no spaces = `None`, one space each side = `Spaces`,
one space on a single side = `SpaceLeft`/`SpaceRight`, and two or more spaces before the delimiter = `Align`.

```powershell
$ini = @'
a=1
b = 2
longkey    =    3
'@ | ConvertFrom-Ini

$ini.PreserveDelimiterSpacing = $true   # each line keeps its own spacing
$ini | ConvertTo-Ini
# a=1
# b = 2
# longkey = 3

$ini.PreserveDelimiterSpacing = $false  # normalize all to DelimiterSpacing
$ini | ConvertTo-Ini
# a = 1
# b = 2
# longkey = 3
```

### `CommentSymbol` / `PreserveCommentSymbols`

```powershell
$ini = @'
; one
# two
'@ | ConvertFrom-Ini

$ini.PreserveCommentSymbols = $true
$ini | ConvertTo-Ini
# ; one
# # two

$ini.PreserveCommentSymbols = $false # normalize all to CommentSymbol (';')
$ini | ConvertTo-Ini
# ; one
# ; two
```

### `PreserveCommentSpacing`

```powershell
$ini = @'
;;;;;;;;;;
;   spaced out
; normal
'@ | ConvertFrom-Ini

$ini.PreserveCommentSpacing = $true
$ini | ConvertTo-Ini
# ;;;;;;;;;;
# ;   spaced out
# ; normal

$ini.PreserveCommentSpacing = $false # normalize to a single space (dividers keep none)
$ini | ConvertTo-Ini
# ;;;;;;;;;;
# ; spaced out
# ; normal
```

### `SortSections` / `SortKeys`

```powershell
$ini = @'
[b]
k = 2

[a]
z = 3
y = 1
'@ | ConvertFrom-Ini

$ini.SortSections = $true
$ini.SortKeys = $true
$ini | ConvertTo-Ini
# [a]
# y = 1
# z = 3
#
# [b]
# k = 2
```

### `StripComments`

```powershell
$ini = @'
[db]
; a comment
host = localhost
'@ | ConvertFrom-Ini

$ini.StripComments = $true
$ini | ConvertTo-Ini
# [db]
# host = localhost
```

### `SectionSpacing`

```powershell
$ini = @'
[a]
x = 1
[b]
y = 2
'@ | ConvertFrom-Ini

$ini.SectionSpacing = 2
$ini | ConvertTo-Ini
# [a]
# x = 1
#
#
# [b]
# y = 2
```

---

## Development

```powershell
# Run the full test suite with coverage (requires Pester 5+)
./Invoke-Tests.ps1 -Coverage

# Generate the documentation site locally (requires PowerShell 7 + Microsoft.PowerShell.PlatyPS)
./Build-Docs.ps1
mkdocs serve   # preview at http://127.0.0.1:8000 (requires mkdocs-material)

# Validate and publish to the PowerShell Gallery
./Publish-PSIniToolkit.ps1 -WhatIf
./Publish-PSIniToolkit.ps1 -ApiKey $env:PSGALLERY_API_KEY
```

## License

[MIT](LICENSE)
