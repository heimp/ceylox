import ceylon.collection {
    ArrayList
}
import ceylon.file {
    parsePath,
    File,
    Visitor
}

"Run the module `lox`."
shared void run() {
    value args = process.arguments;
    if (args.size > 1) {
        print("Usage is: jlox [script]");
    }
    else if (exists arg = args.first, args.size == 1) {
        lox.runFile(arg);
    }
    else {
        print("Welcome to the lox repl");
        lox.runPrompt();
    }
}

shared object lox {

    variable Boolean hadError = false;
    variable Boolean hadRuntimeError = false;

    variable value interpreter = Interpreter();

    suppressWarnings("expressionTypeNothing")
    shared void runFile(String pathString, Boolean exitOnError = true) {
        value resource = parsePath(pathString).resource;
        if (is File resource) {
            run(readUtf8(resource));
            if (exitOnError) {
                if (hadError) {
                     process.exit(65);
                }
                if (hadRuntimeError) {
                    process.exit(70);
                }
            }
        }
    }

    shared void runPrompt() {
        while (true) {
            process.write("> ");
            run(process.readLine() else "");
            hadError = false;
        }
    }

    void run(String source) {
        value scanner = Scanner(source);
        value tokens = scanner.scanTokens();
        value parser = Parser(tokens);
        value statements = parser.parse();
        if (hadError) {
            return;
        }
        value resolver = Resolver(interpreter);
        resolver.resolve(*statements);
        if (hadError) {
            return;
        }
        interpreter.interpret(statements);
    }

    shared void report(Integer line, String where, String message) {
        print("[line ``line``] Error``where``: ``message``");
        hadError = true;
    }

    shared void error(Integer|Token location, String message) {
        if (is Token location) {
            if (location.type == eof) {
                report(location.line, " at end", message);
            } else {
                report(location.line, " at '``location.lexeme``'", message);
            }
        } else {
            report(location, "", message);
        }
    }

    shared  void runtimeError(RuntimeError error) {
        process.writeErrorLine("``error.message`` \n[line ``error.token.line``]");
        hadRuntimeError = true;
    }

    shared void reset() {
        hadError = false;
        hadRuntimeError = false;
        interpreter = Interpreter();
    }
}

shared void runExamples() {
    value root = parsePath("""C:\dev\craftinginterpreters\test""");
    root.visit(object extends Visitor() {

        shared actual void file(File file) {
            if (file.path.string == """C:\dev\craftinginterpreters\test\limit\stack_overflow.lox""") {
                return;
            }
            print("========= the file is ``file`` ==========");
            print(readUtf8(file));
            print("============output===============");
            lox.runFile(file.path.string, false);
            lox.reset();
        }

    });
}

String readUtf8(File file) {
    value array = ArrayList<String>();
    try (reader = file.Reader("UTF-8")) {
        while (exists line = reader.readLine()) {
            array.add(line);
        }
    }
    return "\n".join(array);
}