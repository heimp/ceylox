import ceylon.collection {
    HashMap
}

shared class RuntimeError(token, message) extends Exception() {

    shared Token token;
    shared actual String message;
}

shared class Environment(enclosing = null) satisfies Correspondence<Token, Anything> {

    shared Environment? enclosing;

    value values = HashMap<String, Anything>();

    shared actual Boolean defines(Token key) =>
            key.lexeme in values.keys || (enclosing?.defines(key) else false);

    shared actual Anything get(Token key) {
        if (key.lexeme in values.keys) {
            return values[key.lexeme];
        } else if (exists enclosing) {
            return enclosing.get(key);
        } else {
            throw RuntimeError(key, "Undefined variable ``key.lexeme``");
        }
    }

    "assign is a keyword in Ceylon so I'm calling this reassign instead. As in 're-assign.'"
    shared void reassign(Token key, Anything item) {
        if (key.lexeme in values.keys) {
            values[key.lexeme] = item;
        } else if (exists enclosing) {
            enclosing.reassign(key, item);
        } else {
            throw RuntimeError(key, "Undefined variable: ``string``");
        }
    }

    shared void define(String key, Anything item) {
        values[key] = item;
    }

    shared Environment? ancestor(Integer distance) {
        variable Environment? env = this;
        for (i in 0:distance) {
            env = env?.enclosing;
        }
        return env;
    }

    shared Anything getAt(Integer distance, String key) =>
            ancestor(distance)?.values?.get(key);

    shared void assignAt(Integer distance, Token key, Anything item) {
        ancestor(distance)?.values?.put(key.lexeme, item);
    }

    shared actual String string {
        value result = StringBuilder();
        result.append(values.string);
        if (exists enclosing) {
            result.append(" -> " + enclosing.string);
        }
        return result.string;
    }
}

shared interface LoxCallable {
    shared formal Integer arity;
    shared formal Anything call(Interpreter interpreter, {Anything*} arguments);
}

shared class ReturnThrowable(data) extends Exception() {
    shared Anything data;
}

shared class LoxFunction(declaration, closure, isInitializer) satisfies LoxCallable {

    shared Function declaration;
    shared Environment closure;
    shared Boolean isInitializer;

    shared LoxFunction bind(LoxInstance instance) {
        value environment = Environment(closure);
        environment.define("this", instance);
        return LoxFunction(declaration, environment, isInitializer);
    }

    string => "<fn ``declaration.name.lexeme``>";

    arity => declaration.parameters.size;

    shared actual Anything call(Interpreter interpreter, {Anything*} arguments) {
        value environment = Environment(closure);

        for ([param, arg] in zipPairs(declaration.parameters, arguments)) {
            environment.define(param.lexeme, arg);
        }

        try {
            interpreter.executeBlock(declaration.body, environment);
        }
        catch (ReturnThrowable returnValue) {
            return returnValue.data;
        }

        if (isInitializer) {
            return closure.getAt(0, "this");
        }
        else {
            return null;
        }
    }
}

shared class LoxInstance(klass)
        satisfies Correspondence<Token, Anything> & KeyedCorrespondenceMutator<Token, Anything> {

    shared LoxClass klass;
    value fields = HashMap<String, Anything>();

    shared actual Boolean defines(Token key) => key.lexeme in fields.keys || key.lexeme in klass.methods.keys;

    shared actual Anything get(Token key) {
        if (key.lexeme in fields.keys) {
            return fields[key.lexeme];
        }
        if (exists method = klass.findMethod(this, key.lexeme)) {
            return method;
        }
        throw RuntimeError(key, "Undefined property ``key.lexeme``.");
    }

    shared actual void put(Token key, Anything item) {
        fields[key.lexeme] = item;
    }

    string => "``klass.string`` ``fields``";
}

shared class LoxClass(name, superClass, methods) satisfies LoxCallable {

    shared String name;
    shared LoxClass? superClass;
    shared Map<String, LoxFunction> methods;

    shared LoxFunction? findMethod(LoxInstance instance, String name) =>
            if (exists method = methods[name])
            then method.bind(instance)
            else if (exists superClass)
            then superClass.findMethod(instance, name)
            else null;

    string => name;

    shared actual Integer arity => methods["init"]?.arity else 0;

    shared actual Anything call(Interpreter interpreter, {Anything*} arguments) {
        value instance = LoxInstance(this);
        if (exists initializer = methods["init"]) {
            initializer.bind(instance).call(interpreter, arguments);
        }
        return instance;
    }

}

shared class Interpreter() satisfies ExprVisitor<Anything> & StmtVisitor<Anything> {

    value globals = Environment();
    variable Environment environment = globals;
    value locals = HashMap<Expr, Integer>();
    
    globals.define("clock", object satisfies LoxCallable {
        arity => 0;
        call(Interpreter interpreter, {Anything*} arguments) => (system.milliseconds / 1k).float;
    });

    shared void interpret({Stmt*} statements) {
        try {
            for (stmt in statements) {
                execute(stmt);
            }
        }
        catch (RuntimeError err) {
            lox.runtimeError(err);
        }
    }

    Anything evaluate(Expr expr) => expr.accept(this);

    void execute(Stmt stmt) {
        stmt.accept(this);
    }

    shared void resolve(Expr expr, Integer depth) {
        locals[expr] = depth;
    }

    shared void executeBlock({Stmt*} statements, Environment environment) {
        value previous = this.environment;
        try {
            this.environment = environment;
            for (stmt in statements) {
                execute(stmt);
            }
        }
        finally {
            this.environment = previous;
        }
    }

    shared actual void visitBlockStmt(Block stmt) => executeBlock(stmt.statements, Environment(environment));

    shared actual void visitClassStmt(Class stmt) {
        environment.define(stmt.name.lexeme, null);
        value superClass = if (exists sc = stmt.superClass) then evaluate(sc) else null;
        if (exists superClass) {
            if (!is LoxClass superClass) {
                throw RuntimeError(stmt.name, "Super class must be a class.");
            }
            environment = Environment(environment);
            environment.define("super", superClass);
        }

        value methods = map {
            for (method in stmt.methods)
            method.name.lexeme -> LoxFunction(method, environment, method.name.lexeme == "init")
        };

        assert (is LoxClass? superClass);
        value klass = LoxClass(stmt.name.lexeme, superClass, methods);

        if (exists superClass) {
            assert (exists enclosing = environment.enclosing);
            environment = enclosing;
        }

        environment.reassign(stmt.name, klass);
    }

    shared actual void visitExpressionStmt(Expression stmt) => evaluate(stmt.expression);

    shared actual void visitFunctionStmt(Function stmt) {
        value func = LoxFunction(stmt, environment, false);
        environment.define(stmt.name.lexeme, func);
    }

    shared actual void visitIfStmt(If stmt) {
        if (truthy(evaluate(stmt.condition))) {
            execute(stmt.thenBranch);
        }
        else if (exists elseBranch = stmt.elseBranch){
            execute(elseBranch);
        }
    }

    shared actual void visitPrintStmt(Print stmt) {
        value val = evaluate(stmt.expression);
        print(stringify(val));
    }

    shared actual void visitReturnStmt(Return stmt) {
        if (exists ret = stmt.returnValue) {
            throw ReturnThrowable(evaluate(ret));
        }
        else {
            throw ReturnThrowable(null);
        }
    }

    shared actual void visitVarStmt(Var stmt) {
        value initialValue =
            if (exists init = stmt.initializer)
            then evaluate(init)
            else null;
        environment.define(stmt.name.lexeme, initialValue);
    }

    shared actual void visitWhileStmt(While stmt) {
        while (truthy(evaluate(stmt.condition))) {
            execute(stmt.body);
        }
    }

    shared actual Anything visitAssignExpr(Assign expr) {
        value val = evaluate(expr.assignedValue);
        if (exists distance = locals[expr]) {
            environment.assignAt(distance, expr.name, val);
        }
        else {
            globals.reassign(expr.name, val);
        }
        return val;
    }

    shared actual Anything visitBinaryOpExpr(BinaryOp expr) {
        value left = evaluate(expr.left);
        value right = evaluate(expr.right);
        switch (expr.operator.type)
        case (bangEqual) { return !areEqual(left, right); }
        case (equalEqual) { return areEqual(left, right); }
        case (greater) {
            value [a, b] = checkNumberOperands(expr.operator, left, right);
            return a > b;
        }
        case (greaterEqual) {
            value [a, b] = checkNumberOperands(expr.operator, left, right);
            return a >= b;
        }
        case (less) {
            value [a, b] = checkNumberOperands(expr.operator, left, right);
            return a < b;
        }
        case (lessEqual) {
            value [a, b] = checkNumberOperands(expr.operator, left, right);
            return a <= b;
        }
        case (dash) {
            value [a, b] = checkNumberOperands(expr.operator, left, right);
            return a - b;
        }
        case (cross) {
            if (is Float left, is Float right) {
                return left + right;
            }
            else if (is String left, is String right) {
                return left + right;
            }
            else {
                throw RuntimeError(expr.operator, "Operand must be two numbers or two strings");
            }
        }
        case (star) {
            value [a, b] = checkNumberOperands(expr.operator, left, right);
            return a * b;
        }
        case (slash) {
            value [a, b] = checkNumberOperands(expr.operator, left, right);
            return a / b;
        }
        else { throw RuntimeError(expr.operator, "Not a binary operator."); }
    }

    shared actual Anything visitCallExpr(Call expr) {
        value callee = evaluate(expr.callee);
        if (!is LoxCallable callee) {
            throw RuntimeError(expr.paren, "Can only call functions and classes");
        }
        value arguments = expr.arguments.map(evaluate);
        if (arguments.size != callee.arity) {
            throw RuntimeError(expr.paren, "Expected ``callee.arity`` number of arguments but got ``arguments.size``");
        }
        return callee.call(this, arguments);
    }

    shared actual Anything visitGetterExpr(Getter expr) {
        if (is LoxInstance obj = evaluate(expr.obj)) {
            return obj.get(expr.name);
        }
        else {
            throw RuntimeError(expr.name, "Only instances have properties!");
        }
    }

    shared actual Anything visitGroupingExpr(Grouping expr) => evaluate(expr.expression);

    shared actual Anything visitLiteralExpr(Literal expr) => expr.literalValue;

    shared actual Anything visitLogicalExpr(Logical expr) {
        value left = evaluate(expr.left);
        switch (expr.operator.type)
        case (orKeyword) {
            if (truthy(left)) {
                return left;
            }
        }
        case (andKeyword) {
            if (!truthy(left)) {
                return left;
            }
        }
        else { throw RuntimeError(expr.operator, "Only 'and' or 'or' keywords here."); }
        return evaluate(expr.right);
    }

    shared actual Anything visitSetterExpr(Setter expr) {
        value obj = evaluate(expr.obj);
        if (!is LoxInstance obj) {
            throw RuntimeError(expr.name, "Only instances have properties!");
        }
        value val = evaluate(expr.val);
        obj[expr.name] = val;
        return val;
    }

    shared actual Anything visitSuperExpr(Super expr) {
        if (exists distance = locals[expr]) {
            value superClass = environment.getAt(distance, "super");
            value obj = environment.getAt(distance - 1, "this");
            if (is LoxClass superClass, is LoxInstance obj, exists method = superClass.findMethod(obj, expr.method.lexeme)) {
                return method;
            }
        }
        throw RuntimeError(expr.method, "Undefined property ``expr.method.lexeme``");
    }

    shared actual Anything visitThisExpr(This expr) => lookUpVariable(expr.keyword, expr);

    shared actual Anything visitUnaryOpExpr(UnaryOp expr) {
        value right = evaluate(expr.right);
        switch (expr.operator.type)
        case (bang) { return !truthy(right); }
        case (dash) {
            value number = checkNumberOperand(expr.operator, right);
            return -number;
        }
        else { throw RuntimeError(expr.operator, "Not a valid unary operator!"); }
    }

    shared actual Anything visitVariableExpr(Variable expr) => lookUpVariable(expr.name, expr);

    Anything lookUpVariable(Token name, Expr expr) {
        if (exists distance = locals[expr]) {
            value var = environment.getAt(distance, name.lexeme);
            return var;
        }
        else {
            value var = globals[name];
            return var;
        }
    }

    Float checkNumberOperand(Token operator, Anything operand) {
        if (is Float operand) {
            return operand;
        }
        else {
            throw RuntimeError(operator, "Operand must be a number!");
        }
    }

    Float[2] checkNumberOperands(Token operator, Anything left, Anything right) {
        if (is Float left, is Float right) {
            return [left, right];
        }
        else {
            throw RuntimeError(operator, "Operands must be a numbers!");
        }
    }

    Boolean truthy(Anything anything) =>
            if (!exists anything)
            then false
            else if (is Boolean anything)
            then anything
            else true;

    Boolean areEqual(Anything a, Anything b) {
        if (!exists a, !exists b) {
            return true;
        }
        else if (!exists a) {
            return false;
        }
        else if (!exists b) {
            return false;
        }
        else {
            return a == b;
        }
    }

    String stringify(Anything anything) =>
            if (!exists anything)
            then "nil"
            else if (is Float anything)
            then anything.integer.string
            else anything.string;
    
}