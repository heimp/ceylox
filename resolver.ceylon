import ceylon.collection {
    ArrayList,
    HashMap
}

shared class Resolver(interpreter) satisfies ExprVisitor<Anything> & StmtVisitor<Anything> {

    Interpreter interpreter;

    value scopes = ArrayList<HashMap<String, Boolean>>();

    variable value currentFunction = FunctionType.none;
    variable value currentClass = ClassType.none;

    shared void resolve(<Stmt|Expr>* elements) {
        for (element in elements) {
            if (is Stmt element) {
                element.accept(this);
            }
            else {
                element.accept(this);
            }
        }
    }

    shared actual void visitBlockStmt(Block stmt) {
        beginScope();
        resolve(*stmt.statements);
        endScope();
    }

    shared actual void visitClassStmt(Class stmt) {
        declare(stmt.name);
        define(stmt.name);
        value enclosingClass = currentClass;
        currentClass = ClassType.\iclass;
        if (exists superClass = stmt.superClass) {
            currentClass = ClassType.subClass;
            resolve(superClass);
            beginScope();
            scopes.top?.put("super", true);
        }
        beginScope();
        scopes.top?.put("this", true);
        for (method in stmt.methods) {
            value declaration = method.name.lexeme == "init" then FunctionType.initializer else FunctionType.method;
            resolveFunction(method, declaration);
        }
        endScope();
        if (stmt.superClass exists) {
            endScope();
        }
        currentClass = enclosingClass;
    }

    shared actual void visitExpressionStmt(Expression stmt) => resolve(stmt.expression);

    shared actual void visitFunctionStmt(Function stmt) {
        declare(stmt.name);
        define(stmt.name);
        resolveFunction(stmt, FunctionType.\ifunction);
    }

    shared actual void visitIfStmt(If stmt) {
        resolve(stmt.condition);
        resolve(stmt.thenBranch);
        if (exists elseBranch = stmt.elseBranch) {
            resolve(elseBranch);
        }
    }

    shared actual void visitPrintStmt(Print stmt) => resolve(stmt.expression);

    shared actual void visitReturnStmt(Return stmt) {
        if (currentFunction == FunctionType.none) {
            lox.error(stmt.keyword, "Cannot return from top level code");
        }
        if (exists val = stmt.returnValue) {
            if (currentFunction == FunctionType.initializer) {
                lox.error(stmt.keyword, "Cannot return a value from an initializer");
            }
            resolve(val);
        }
    }

    shared actual void visitVarStmt(Var stmt) {
        declare(stmt.name);
        if (exists initialVal = stmt.initializer) {
            resolve(initialVal);
        }
        define(stmt.name);
    }

    shared actual void visitWhileStmt(While stmt) {
        resolve(stmt.condition);
        resolve(stmt.body);
    }

    shared actual void visitAssignExpr(Assign expr) {
        resolve(expr.assignedValue);
        resolveLocal(expr, expr.name);
    }

    shared actual void visitBinaryOpExpr(BinaryOp expr) {
        resolve(expr.left);
        resolve(expr.right);
    }

    shared actual void visitCallExpr(Call expr) {
        resolve(expr.callee);
        expr.arguments.each(resolve);
    }

    shared actual void visitGetterExpr(Getter expr) => resolve(expr.obj);

    shared actual void visitGroupingExpr(Grouping expr) => resolve(expr.expression);

    shared actual void visitLiteralExpr(Literal expr) {}

    shared actual void visitLogicalExpr(Logical expr) {
        resolve(expr.left);
        resolve(expr.right);
    }

    shared actual void visitSetterExpr(Setter expr) {
        resolve(expr.val);
        resolve(expr.obj);
    }

    shared actual void visitSuperExpr(Super expr) {
        if (currentClass == ClassType.none) {
            lox.error(expr.keyword, "Can't use super outside of a class");
        }
        else if (currentClass != ClassType.subClass) {
            lox.error(expr.keyword, "Can't use super in a class with no superclass");
        }
        resolveLocal(expr, expr.keyword);
    }

    shared actual void visitThisExpr(This expr) {
        if (currentClass == ClassType.none) {
            lox.error(expr.keyword, "Can't use 'this' outside of a class");
        }
        else {
            resolveLocal(expr, expr.keyword);
        }
    }

    shared actual void visitUnaryOpExpr(UnaryOp expr) => resolve(expr.right);

    shared actual void visitVariableExpr(Variable expr) {
        if (exists scope = scopes.top, exists defined = scope[expr.name.lexeme], !defined) {
            lox.error(expr.name, "Cannot read local variable in its own initializer");
        }
        resolveLocal(expr, expr.name);
    }

    void resolveFunction(Function func, FunctionType type) {
        value enclosingFunction = currentFunction;
        currentFunction = type;

        beginScope();
        for (param in func.parameters) {
            declare(param);
            define(param);
        }
        resolve(*func.body);
        endScope();

        currentFunction = enclosingFunction;
    }

    void beginScope() { scopes.push(HashMap<String, Boolean>()); }

    void endScope() { scopes.pop(); }

    void declare(Token name) {
        if (exists scope = scopes.top) {
            if (name.lexeme in scope.keys) {
                lox.error(name, "Variable with this name already declared in this scope");
            }
            scope[name.lexeme] = false;
        }
    }

    void define(Token name) {
        if (exists scope = scopes.top) {
            scope[name.lexeme] = true;
        }
    }

    void resolveLocal(Expr expr, Token name) {
        for (depth->scope in scopes.reversed.indexed) {
            if (exists var = scope[name.lexeme]) {
                interpreter.resolve(expr, depth);
                return;
            }
        }
    }
}

class FunctionType of none | \ifunction | initializer | method {
    shared new none {}
    shared new \ifunction {}
    shared new initializer {}
    shared new method {}
}

class ClassType of none | \iclass | subClass {
    shared new none {}
    shared new \iclass {}
    shared new subClass {}
}