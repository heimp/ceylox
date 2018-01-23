shared abstract class TokenType() of
        PunctuationTokenType | MetaTokenType | KeywordTokenType  {}

shared abstract class PunctuationTokenType() of
        leftParen | rightParen | leftBrace | rightBrace |
        comma | dot | dash | cross | semicolon | slash | star |
        bang | bangEqual |
        equalSign | equalEqual |
        greater | greaterEqual |
        less | lessEqual
        extends TokenType() {}

shared object leftParen extends PunctuationTokenType() { string => "("; }
shared object rightParen extends PunctuationTokenType() { string => "("; }
shared object leftBrace extends PunctuationTokenType() { string => "{"; }
shared object rightBrace extends PunctuationTokenType() { string => "}"; }

shared object comma extends PunctuationTokenType() { string => ","; }
shared object dot extends PunctuationTokenType() { string => "."; }
shared object dash extends PunctuationTokenType() { string => "-"; }
shared object cross extends PunctuationTokenType() { string => "+"; }
shared object semicolon extends PunctuationTokenType() { string => ";"; }
shared object slash extends PunctuationTokenType() { string => "/"; }
shared object star extends PunctuationTokenType() { string => "*"; }

shared object bang extends PunctuationTokenType() { string => "!"; }
shared object bangEqual extends PunctuationTokenType() { string => "!="; }
shared object equalSign extends PunctuationTokenType() { string => "="; }
shared object equalEqual extends PunctuationTokenType() { string => "=="; }
shared object greater extends PunctuationTokenType() { string => ">"; }
shared object greaterEqual extends PunctuationTokenType() { string => ">="; }
shared object less extends PunctuationTokenType() { string => "<"; }
shared object lessEqual extends PunctuationTokenType() { string => "<="; }

shared abstract class MetaTokenType() of
        identifier | quotedString | number | eof
        extends TokenType() {}

shared object identifier extends MetaTokenType() { string => "<id>"; }
shared object quotedString extends MetaTokenType() { string => "<string>"; }
shared object number extends MetaTokenType() { string => "<number>"; }
shared object eof extends MetaTokenType() { string => "<eof>"; }


shared abstract class KeywordTokenType() of
        andKeyword | classKeyword | elseKeyword | falseKeyword |
        funKeyword | forKeyword | ifKeyword | nilKeyword | orKeyword |
        printKeyword | returnKeyword | superKeyword | thisKeyword | trueKeyword |
        varKeyword | whileKeyword
        extends TokenType() {}

shared object andKeyword extends KeywordTokenType() { string => "and"; }
shared object classKeyword extends KeywordTokenType() { string => "class"; }
shared object elseKeyword extends KeywordTokenType() { string => "else"; }
shared object falseKeyword extends KeywordTokenType() { string => "false"; }
shared object funKeyword extends KeywordTokenType() { string => "fun"; }
shared object forKeyword extends KeywordTokenType() { string => "for"; }
shared object ifKeyword extends KeywordTokenType() { string => "if"; }
shared object nilKeyword extends KeywordTokenType() { string => "nil"; }
shared object orKeyword extends KeywordTokenType() { string => "or"; }
shared object printKeyword extends KeywordTokenType() { string => "print"; }
shared object returnKeyword extends KeywordTokenType() { string => "return"; }
shared object superKeyword extends KeywordTokenType() { string => "super"; }
shared object thisKeyword extends KeywordTokenType() { string => "this"; }
shared object trueKeyword extends KeywordTokenType() { string => "true"; }
shared object varKeyword extends KeywordTokenType() { string => "var"; }
shared object whileKeyword extends KeywordTokenType() { string => "while"; }

shared Map<String, KeywordTokenType> keywords = map { for(type in `KeywordTokenType`.caseValues) type.string -> type };

//shared abstract class LoxNil() of nil {}
//shared object nil extends LoxNil() { string => "nil"; }

shared alias LiteralValue => String|Float|Boolean|Null;

shared class Token(type, lexeme, line, literal = null) {

    shared TokenType type;
    shared String lexeme;
    shared Integer line;
    shared LiteralValue literal;

    string =>
            switch (type)
            case (is MetaTokenType) "[``type`` ``lexeme``]"
            else "[``lexeme``]";
}

