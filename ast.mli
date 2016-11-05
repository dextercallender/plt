(* Abstract Syntax Tree *)
type binopr =
    Add
  | Sub
  | Mult
  | Div
  | Eq
  | Neq
  | Lt
  | Leq
  | Gt
  | Geq
  | And
  | Or

type typ =
    Int
  | Double
  | Char
  | String
  | Bool
  | Void

type bind = typ * string

type expr =
    Binop of expr * binopr * expr
  | IntLit of int
  | DoubleLit of float
  | StrLit of string
  | CharLit of char
  | BoolLit of bool
  | Id of string
  | Asn of string * expr
  | Seq of expr * expr

type stmt = 
    Block of stmt list
  | Expr of expr
  | Return of expr
  | If of expr * stmt * stmt
  | For of expr * stmt * stmt

type func_decl = {
    typ : typ;
    fname : string;
    formals : bind list;
    locals : bind list;
    body : stmt list;
  }

type program = bind list * func_decl list


