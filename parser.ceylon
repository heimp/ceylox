import ceylon.collection {
    ArrayList
}
shared class ParseError() extends Exception() {}

shared class Parser({Token*} tokenStream) {

    value tokens = tokenStream.sequence();
    variable value current = 0;

    shared {Stmt*} parse() {
        value statements = ArrayList<Stmt?>();
        while (!atEnd) {
            statements.add(declaration());
        }
        return statements.coalesced;
    }

    Expr expression() => assignment();

    Stmt? declaration() {
        try {
            if (match(classKeyword)) {
                return classDeclaration();
            }
            if (match(funKeyword)) {
                return fun("function");
            }
            if (match(varKeyword)) {
                return varDeclaration();
            }
            return statement();
        }
        catch (ParseError e) {
            synchronize();
            return null;
        }
    }

    Stmt classDeclaration() {
        value name = consume(identifier, "Expect a class name after the class keyword.");
        variable Expr? superClass = null;
        if (match(less)) {
            consume(identifier, "Exprect a super class name after <.");
            superClass = Variable(previous);
        }
        consume(leftBrace, "Expect { before class body.");
        value methods = ArrayList<Function>();
        while (!check(rightBrace) && !atEnd) {
            methods.add(fun("method"));
        }
        consume(rightBrace, "Expect } after class body.");
        assert (exists name);
        return Class(name, superClass, methods);
    }

    Stmt statement() =>
            if (match(forKeyword))
            then forStatement()
            else if (match(ifKeyword))
            then ifStatement()
            else if (match(printKeyword))
            then printStatement()
            else if (match(returnKeyword))
            then returnStatement()
            else if (match(whileKeyword))
            then whileStatement()
            else if (match(leftBrace))
            then Block(block())
            else expressionStatement();

    Stmt forStatement() {
        consume(leftParen, "Expect ( after for.");
        value initializer = if (match(semicolon)) then null else if (match(varKeyword)) then varDeclaration() else expressionStatement();
        value condition = !check(semicolon) then expression() else Literal(true);
        consume(semicolon, "Expect ; after loop condition.");
        value increment = !check(rightParen) then expression();
        consume(rightParen, "Expect ) after for loop clauses.");

        /* turns for(init; condition; increment) { body }
           into { init; while(condition) { body; increment; } }
           or for(;;) { body }
           into while(true) { body }
           or some variation on that theme
         */

        value body = statement();
        if (exists increment, exists initializer) {
            return Block { initializer, While(condition, Block { body, Expression(increment) }) };
        }
        else if (exists increment) {
            return While(condition, Block { body, Expression(increment) });
        }
        else if (exists initializer) {
            return Block { initializer, While(condition, body) };
        }
        else {
            return While(condition, body);
        }
    }

    Stmt ifStatement() {
        consume(leftParen, "Expect ( after if.");
        value condition = expression();
        consume(rightParen, "Expect ) after condition");
        value thenBranch = statement();
        value elseBranch =  match(elseKeyword) then statement();
        return If(condition, thenBranch, elseBranch);
    }
    Stmt printStatement() {
        value expr = expression();
        consume(semicolon, "Expect ; after print statement.");
        return Print(expr);
    }

    Stmt returnStatement() {
        value keyword = previous;
        value returnValue = !check(semicolon) then expression();
        consume(semicolon, "Expect ; after return statement.");
        return Return(keyword, returnValue);
    }

    Stmt varDeclaration() {
        value name = consume(identifier, "Expect a variable name here.");
        value initializer = match(equalSign) then expression();
        consume(semicolon, "Expect ; after a variable declaration.");
        assert (exists name);
        return Var(name, initializer);
    }

    Stmt whileStatement() {
        consume(leftParen, "Expect ( after while.");
        value condition = expression();
        consume(rightParen, "Expect ) after while loop condition");
        value body = statement();
        return While(condition, body);
    }

    Stmt expressionStatement() {
        value expr = expression();
        consume(semicolon, "Expect ; after expression.");
        return Expression(expr);
    }

    Function fun(String kind) {
        value name = consume(identifier, "Expect ``kind`` name.");
        consume(leftParen, "Expect a ( after ``kind`` name.");
        value parameters = ArrayList<Token>();
        if (!check(rightParen)) {
            while (true) {
                if (parameters.size > 8) {
                    error(peek, "Cannot have more than 8 parameters.");
                }
                if (exists id = consume(identifier, "Expect parameter name.")) {
                    parameters.add(id);
                }
                if (!match(comma)) {
                    break;
                }
            }
        }
        consume(rightParen, "Expect ) after parameter list.");
        consume(leftBrace, "Expect { before ``kind`` body.");
        value body = block();
        assert (exists name);
        return Function(name, parameters, body);
    }

    {Stmt*} block() {
        value statements = ArrayList<Stmt?>();
        while (!check(rightBrace) && !atEnd) {
            statements.add(declaration());
        }
        consume(rightBrace, "Expect } after block.");
        return statements.coalesced;
    }

    Expr assignment() {
        variable value expr = or();
        if (match(equalSign)) {
            value equalsToken = previous;
            value rightValue = assignment();
            if (is Variable var = expr) {
                return Assign(var.name, rightValue);
            } else if (is Getter getter = expr) {
                return Setter(getter.obj, getter.name, rightValue);
            }
            error(equalsToken, "Invalid assignment target.");
        }
        return expr;
    }

    Expr or() {
        variable value expr = and();
        while (match(orKeyword)) {
            value operator = previous;
            value right = and();
            expr = BinaryOp(expr, operator, right);
        }
        return expr;
    }

    Expr and() {
        variable value expr = equality();
        while (match(andKeyword)) {
            value operator = previous;
            value right = equality();
            expr = BinaryOp(expr, operator, right);
        }
        return expr;
    }

    Expr equality() {
        variable value expr = comparison();
        while (match(equalEqual, bangEqual)) {
            value operator = previous;
            value right = comparison();
            expr = BinaryOp(expr, operator, right);
        }
        return expr;
    }

    Expr comparison() {
        variable value expr = addition();
        while (match(less, lessEqual, greater, greaterEqual)) {
            value operator = previous;
            value right = addition();
            expr = BinaryOp(expr, operator, right);
        }
        return expr;
    }

    Expr addition() {
        variable value expr = multiplication();
        while (match(dash, cross)) {
            value operator = previous;
            value right = multiplication();
            expr = BinaryOp(expr, operator, right);
        }
        return expr;
    }

    Expr multiplication() {
        variable value expr = unary();
        while (match(slash, star)) {
            value operator = previous;
            value right = unary();
            expr = BinaryOp(expr, operator, right);
        }
        return expr;
    }

    Expr unary() {
        if (match(bang, dash)) {
            value operator = previous;
            value right = unary();
            return UnaryOp(operator, right);
        }
        return call();
    }

    Expr finishCall(Expr callee) {
        value arguments = ArrayList<Expr>();
        if (!check(rightParen)) {
            while (true) {
                if (arguments.size > 8) {
                    error(peek, "Cannot have more than 8 arguments");
                }
                arguments.add(expression());
                if (!match(comma)) {
                    break;
                }
            }
        }
        assert (exists paren = consume(rightParen, "Expect a ) after arguments."));
        return Call(callee, paren, arguments);
    }

    Expr call() {
        variable value expr = primary();
        while(true) {
            if(match(leftParen)) {
                assert(exists e = expr);
                expr = finishCall(e);
            } else if(match(dot)) {
                value name = consume(identifier, "expect property name after '.'.");
                assert(exists e = expr, exists name);
                expr = Getter(e, name);
            } else {
                break;
            }
        }
        assert (exists e = expr);
        return e;
    }

    Expr? primary() {
        if (match(falseKeyword)) {
            return Literal(false);
        }
        if (match(trueKeyword)) {
            return Literal(true);
        }
        if (match(nilKeyword)) {
            return Literal(null);
        }
        if (match(number, quotedString)) {
            return Literal(previous.literal);
        }
        if(match(superKeyword)) {
            value keyword = previous;
            consume(dot, "Expect . after super");
            value method = consume(identifier, "Expect superclass method name");
            assert (exists method);
            return Super(keyword, method);
        }
        if(match(thisKeyword)) {
            return This(previous);
        }
        if(match(identifier)) {
            return Variable(previous);
        }
        if(match(leftParen)) {
            value expr = expression();
            consume(rightParen, "Expect a ')' after expression.");
            return Grouping(expr);
        }

        throw error(peek, "Expect expression.");
    }

    Boolean match(TokenType* types) {
        for (type in types) {
            if (check(type)) {
                advance();
                return true;
            }
        }
        return false;
    }

    Token? consume(TokenType type, String message) {
        if (check(type)) {
            return advance();
        }
        throw error(peek, message);
    }

    Boolean check(TokenType tokenType) {
        if (atEnd) {
            return false;
        }
        return peek.type == tokenType;
    }

    Token? advance() {
        if(!atEnd) {
            current++;
        }
        return previous;
    }

    Boolean atEnd => peek.type == eof;

    Token peek {
        assert (exists token = tokens[current]);
        return token;
    }

    Token previous {
        assert (exists token = tokens[current - 1]);
        return token;
    }

    ParseError error(Token token, String message) {
        lox.error(token, message);
        return ParseError();
    }

    void synchronize() {
        advance();
        while (!atEnd) {
            if (previous.type == semicolon) {
                return;
            }
            if (peek.type in [classKeyword, funKeyword, varKeyword, forKeyword, ifKeyword, whileKeyword, printKeyword, returnKeyword]) {
                return;
            }
            advance();
        }
    }
}

