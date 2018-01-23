import ceylon.collection {
    ArrayList
}

shared class Scanner(String source) {

    value tokens = ArrayList<Token>();
    variable value start = 0;
    variable value current = 0;
    variable value line = 1;

    shared {Token*} scanTokens() {

        while (!isAtEnd) {
            start = current;
            scanToken();
        }

        tokens.add(Token(eof, "", line));
        return tokens;
    }

    void scanToken() {
        value c = advance();
        switch (c)
        case ('(') {
            addToken(leftParen);
        }
        case (')') {
            addToken(rightParen);
        }
        case ('{') {
            addToken(leftBrace);
        }
        case ('}') {
            addToken(rightBrace);
        }
        case (',') {
            addToken(comma);
        }
        case ('.') {
            addToken(dot);
        }
        case ('-') {
            addToken(dash);
        }
        case ('+') {
            addToken(cross);
        }
        case (';') {
            addToken(semicolon);
        }
        case ('*') {
            addToken(star);
        }
        case ('!') {
            addToken(match('=') then bangEqual else bang);
        }
        case ('=') {
            addToken(match('=') then equalEqual else equalSign);
        }
        case ('<') {
            addToken(match('=') then lessEqual else less);
        }
        case ('>') {
            addToken(match('=') then greaterEqual else greater);
        }
        case ('/') {
            if (peek == '/') {
                while (peek != '\n' && !isAtEnd) {
                    advance();
                }
            } else {
                addToken(slash);
            }
        }
        case (' '|'\t'|'\r') {}
        case ('\n') {
            line++;
        }
        case ('"') {
            scanString();
        }
        else {
            if (c.digit) {
                scanNumber();
            } else if (isAlpha(c)) {
                scanIdentifier();
            } else {
                lox.error(line, "Unexpected character");
            }
        }
    }


    void scanIdentifier() {
        while (isAlphaNumeric(peek)) {
            advance();
        }
        value text = source[start..current - 1];
        if (exists keywordType = keywords[text]) {
            addToken(keywordType);
        } else {
            addToken(identifier);
        }
    }

    void scanNumber() {
        while (peek.digit) {
            advance();
        }
        if (peek == '.' && peekNext.digit) {
            advance();
        }
        while (peek.digit) {
            advance();
        }
        value text = source[start..current - 1];
        value literal =
            if (is Float float = Float.parse(text))
            then float
            else null;
        assert (exists literal);
        addToken(number, literal);
    }

    void scanString() {
        while (peek != '"' && !isAtEnd) {
            if (peek == '\n') {
                line++;
            }
            advance();
        }
        if (isAtEnd) {
            print("unterminated string on line ``line``. don't forget your quotation mark!");
            return;
        }
        advance();
        String text = source[(start + 1)..(current - 2)];
        addToken(quotedString, text);
    }

    Boolean match(Character c) {
        if (isAtEnd) {
            return false;
        }
        if (exists currentChar = source[current], currentChar != c) {
            return false;
        }
        current++;
        return true;
    }

    Character peek => source[current] else '\0';
    Character peekNext => source[current + 1] else '\0';

    Boolean isAlpha(Character c) => c.letter || c == '_';
    Boolean isAlphaNumeric(Character c) => isAlpha(c) || c.digit;

    Boolean isAtEnd => current>=source.size;

    Character advance() {
        current++;
        return source[current - 1] else '\0';
    }

    void addToken(TokenType type, LiteralValue? literal = null) {
        value text = source[start..current - 1];
        tokens.add(Token(type, text,  line, literal));
    }
}

