/* PARSER.MLY for BLUR */

%{ open Ast %}

%token LPAREN RPAREN LBRACE RBRACE LBRACK RBRACK ARR
%token SEMI COMMA FUNC
%token INT DOUBLE STRING CHAR BOOL
%token IF ELSE FOR WHILE VOID RETURN TRUE FALSE BREAK CONTINUE
%token PLUS MINUS TIMES DIVIDE ASSIGN
%token EQUAL NEQUAL LT LEQ GT GEQ AND OR NOT
%token <string> ID
%token <int> INT_LITERAL
%token <float> DOUBLE_LITERAL
%token <bool> BOOL_LITERAL
%token <string> STRING_LITERAL
%token <char> CHAR_LITERAL
%token EOF

%nonassoc NOELSE
%nonassoc ELSE
%right ASSIGN
%left AND OR
%left EQUAL NEQUAL
%left LT GT LEQ GEQ
%left PLUS MINUS
%left TIMES DIVIDE
%right NOT
%nonassoc UNOP

%start program
%type <Ast.program> program

%%

program:
decls EOF { List.rev $1 }

decls:
    /* nothing */ { [] }
  | decls vardecl SEMI { Vardecl($2) :: $1 } 
  | decls funcdecl { Funcdecl($2) :: $1 }

funcdecl:
    typ ID LPAREN args_list RPAREN LBRACE stmt_list RBRACE
    {
        {
            typ = $1;
            fname = $2;
            args = $4;
            body = $7;
        }
    }

args_list:
    /* nothing */ { [] }
  | argdecl       { [$1] }
  | argdecl COMMA args_list { $1 :: $3 } 

argdecl:
    simple_vardecl {$1}

/* maybe canvas goes here later? */
typ:
    INT { Int }
  | DOUBLE { Double }
  | CHAR { Char }
  | STRING { String }
  | BOOL { Bool }
  | VOID { Void }
  | ARR typ LBRACK RBRACK { Array($2) }

vardecl:
    simple_vardecl { $1 }
  | vardecl_init   { $1 }  

simple_vardecl:
    typ ID {{declTyp = $1;
             declID = $2;
             declInit = Noexpr}}
vardecl_init:
    typ ID ASSIGN expr {{declTyp = $1;
                         declID = $2;
                         declInit = $4}}
stmt_list:
    stmt { [$1] }
  | stmt stmt_list { $1 :: $2 }

stmt:
    expr_stmt           { $1 }
  | vardecl SEMI        { Decl($1) }
  | condit_stmt         { $1 }
  | loop_stmt           { $1 }

expr_stmt:
    expr SEMI { Expr($1) }

condit_stmt:
    IF LPAREN expr RPAREN stmt %prec NOELSE { If($3, $5, Expr(Noexpr)) }
  | IF LPAREN expr RPAREN stmt ELSE stmt   { If($3, $5, $7) }

loop_stmt:
    FOR LPAREN expr_opt SEMI expr_opt SEMI expr_opt RPAREN stmt { For($3, $5, $7, $9) }
  | WHILE LPAREN expr RPAREN stmt { While($3, $5) }

expr_opt:
         { Noexpr }
  | expr { $1 }

expr_list:
    expr                 { [$1] }
  | expr COMMA expr_list { $1::$3 }

expr:
    INT_LITERAL       { IntLit($1) }
  | DOUBLE_LITERAL    { DoubleLit($1) }
  | STRING_LITERAL    { StrLit($1) }
  | CHAR_LITERAL      { CharLit($1) }
  | BOOL_LITERAL      { BoolLit($1) }
  | ID                { Id($1) }
  | expr PLUS expr    { Binop($1, Add, $3) }
  | expr MINUS expr   { Binop($1, Sub, $3) }
  | expr TIMES expr   { Binop($1, Mult, $3) }
  | expr DIVIDE expr  { Binop($1, Div, $3) }
  | expr EQUAL expr   { Binop($1, Eq, $3) }
  | expr NEQUAL expr  { Binop($1, Neq, $3) }
  | expr LT expr      { Binop($1, Lt, $3) }
  | expr LEQ expr     { Binop($1, Leq, $3) }
  | expr GT expr      { Binop($1, Gt, $3) }
  | expr GEQ expr     { Binop($1, Geq, $3) }
  | expr AND expr     { Binop($1, And, $3) }
  | expr OR expr      { Binop($1, Or, $3) }
  | LPAREN expr RPAREN { $2 }
  | ID ASSIGN expr    { Binop(Id($1), Asn, $3) }
  | LBRACE expr_list RBRACE { ArrayListInit($2) }
  | typ LBRACK INT_LITERAL RBRACK { ArraySizeInit($1, $3) }
  | func_call         { $1 }

func_call:
    ID LPAREN RPAREN            { FuncCall($1, []) }
  | ID LPAREN expr_list RPAREN  { FuncCall($1, $3) }


