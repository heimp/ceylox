shared interface StmtVisitor<Result> {
    shared formal Result visitBlockStmt(Block stmt);
    shared formal Result visitClassStmt(Class stmt);
    shared formal Result visitExpressionStmt(Expression stmt);
    shared formal Result visitFunctionStmt(Function stmt);
    shared formal Result visitIfStmt(If stmt);
    shared formal Result visitPrintStmt(Print stmt);
    shared formal Result visitReturnStmt(Return stmt);
    shared formal Result visitVarStmt(Var stmt);
    shared formal Result visitWhileStmt(While stmt);
}

shared abstract class Stmt() of
        Block | Class | Expression |
        Function | If | Print |
        Return | Var | While {

    shared formal Result accept<out Result>(StmtVisitor<Result> visitor);

}

shared class Block(shared {Stmt*} statements) extends Stmt() {
    shared actual Result accept<Result>(StmtVisitor<Result> visitor) => visitor.visitBlockStmt(this);

    string => "``statements``";
}

shared class Class(shared Token name, shared Expr? superClass, shared {Function*} methods) extends Stmt() {
    shared actual Result accept<Result>(StmtVisitor<Result> visitor) => visitor.visitClassStmt(this);

    string => "class ``name`` ``if (exists superClass) then " < ``superClass``" else ""`` ``methods``";
}

shared class Expression(shared Expr expression) extends Stmt() {
    shared actual Result accept<Result>(StmtVisitor<Result> visitor) => visitor.visitExpressionStmt(this);

    string => expression.string;
}

shared class Function(shared Token name, shared {Token*} parameters, shared {Stmt*} body) extends Stmt() {
    shared actual Result accept<Result>(StmtVisitor<Result> visitor) => visitor.visitFunctionStmt(this);

    string => "fun ``name``(``", ".join(parameters)``) ``body``";
}

shared class If(shared Expr condition, shared Stmt thenBranch, shared Stmt? elseBranch) extends Stmt() {
    shared actual Result accept<Result>(StmtVisitor<Result> visitor) => visitor.visitIfStmt(this);

    string => "if (``condition``) then ``thenBranch.string``" + (if (exists elseBranch) then " else ``elseBranch``" else "");
}

shared class Print(shared Expr expression) extends Stmt() {
    shared actual Result accept<Result>(StmtVisitor<Result> visitor) => visitor.visitPrintStmt(this);

    string => "print ``expression``";
}

shared class Return(shared Token keyword, shared Expr? returnValue) extends Stmt() {
    shared actual Result accept<Result>(StmtVisitor<Result> visitor) => visitor.visitReturnStmt(this);

    string => "return ``returnValue else "nil"``";
}

shared class Var(shared Token name, shared Expr? initializer) extends Stmt() {
    shared actual Result accept<Result>(StmtVisitor<Result> visitor) => visitor.visitVarStmt(this);

    string => "var ``name`` = ``initializer else "nil"``";
}

shared class While(shared Expr condition, shared Stmt body) extends Stmt() {
    shared actual Result accept<Result>(StmtVisitor<Result> visitor) => visitor.visitWhileStmt(this);

    string => "while (``condition``) ``body``";
}

