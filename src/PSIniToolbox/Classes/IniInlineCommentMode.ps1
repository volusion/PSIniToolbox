enum IniInlineCommentMode {
    # Values are taken verbatim; no inline comments are parsed
    None

    # The first occurrence of the document's comment symbol in a value starts the inline comment
    First

    # The last occurrence of the document's comment symbol in a value starts the inline comment
    Last
}
