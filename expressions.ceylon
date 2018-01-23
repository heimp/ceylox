shared interface ExprVisitor<Result> {
    shared formal Result visitAssignExpr(Assign expr);
    shared formal Result visitBinaryOpExpr(BinaryOp expr);
    shared formal Result visitCallExpr(Call expr);
    shared formal Result visitGetterExpr(Getter expr);
    shared formal Result visitGroupingExpr(Grouping expr);
    shared formal Result visitLogicalExpr(Logical expr);
    shared formal Result visitLiteralExpr(Literal expr);
    shared formal Result visitSetterExpr(Setter expr);
    shared formal Result visitSuperExpr(Super expr);
    shared formal Result visitThisExpr(This expr);
    shared formal Result visitUnaryOpExpr(UnaryOp expr);
    shared formal Result visitVariableExpr(Variable expr);
}

shared abstract class Expr() of
        Assign | BinaryOp | Call |
        Getter | Grouping | Literal |
        Logical | Setter | Super |
        This | UnaryOp | Variable {

    shared formal Result accept<Result>(ExprVisitor<Result> visitor);
}

shared class Assign(shared Token name, shared Expr assignedValue) extends Expr() {
    shared actual Result accept<Result>(ExprVisitor<Result> visitor) => visitor.visitAssignExpr(this);

    string => "``name`` = ``assignedValue``";
}

shared class BinaryOp(shared Expr left, shared Token operator, shared Expr right) extends Expr() {
    shared actual Result accept<Result>(ExprVisitor<Result> visitor) => visitor.visitBinaryOpExpr(this);

    string => "``left`` ``operator`` ``right``";
}

shared class Call(shared Expr callee, shared Token paren, shared {Expr*} arguments) extends Expr() {
    shared actual Result accept<Result>(ExprVisitor<Result> visitor) => visitor.visitCallExpr(this);

    string => "call ``callee``(``", ".join(arguments)``)";
}

shared class Getter(shared Expr obj, shared Token name) extends Expr() {
    shared actual Result accept<Result>(ExprVisitor<Result> visitor) => visitor.visitGetterExpr(this);

    string => "``obj``.``name``";
}

shared class Grouping(shared Expr expression) extends Expr() {
    shared actual Result accept<Result>(ExprVisitor<Result> visitor) => visitor.visitGroupingExpr(this);

    string => "(``expression``)";
}

shared class Literal(shared LiteralValue literalValue) extends Expr() {
    shared actual Result accept<Result>(ExprVisitor<Result> visitor) => visitor.visitLiteralExpr(this);

    string =>
            switch (literalValue)
            case (is Float|Boolean) literalValue.string
            case (is String) literalValue
            case (is Null) "nil";
}

shared class Logical(shared Expr left, shared Token operator, shared Expr right) extends Expr() {
    shared actual Result accept<Result>(ExprVisitor<Result> visitor) => visitor.visitLogicalExpr(this);

    string => "``left`` ``operator`` ``right``";
}

shared class Setter(shared Expr obj, shared Token name, shared Expr val) extends Expr() {
    shared actual Result accept<Result>(ExprVisitor<Result> visitor) => visitor.visitSetterExpr(this);

    string => "``obj``.``name`` = ``val``";
}

shared class Super(shared Token keyword, shared Token method) extends Expr() {
    shared actual Result accept<Result>(ExprVisitor<Result> visitor) => visitor.visitSuperExpr(this);

    string => "super";
}

shared class This(shared Token keyword) extends Expr() {
    shared actual Result accept<Result>(ExprVisitor<Result> visitor) => visitor.visitThisExpr(this);

    string => "this";
}

shared class UnaryOp(shared Token operator, shared Expr right) extends Expr() {
    shared actual Result accept<Result>(ExprVisitor<Result> visitor) => visitor.visitUnaryOpExpr(this);

    string => "``operator````right``";
}

shared class Variable(shared Token name) extends Expr() {
    shared actual Result accept<Result>(ExprVisitor<Result> visitor) => visitor.visitVariableExpr(this);

    string => name.string;
}

