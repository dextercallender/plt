open Ast

module A = Ast

(*open Sast*) 

module StringMap = Map.Make(String)

type symbol_table = {
    parent: symbol_table option;
    args: argdecl list;
    variables: vardecl list
}

type func_entry = {
    name: string;
    arg_types: datatype list;
    return_type: datatype
}

type env = {
    symtab: symbol_table;
    funcs: func_entry list;
    return_type: datatype option
}

let check_prog (globals, functions) = 
	(* Add global variable declarations to the symbol table *)
	print_endline("checking prog");

	(* A global variable cannot have type void. *)
	let check_not_void (vdecl : vardecl) = 
		(* Get the types of the globals *)
		let global_typ = (fun v -> v.declTyp) vdecl in
				if global_typ = Datatype(Void) then raise 
					(Failure ("illegal void variable " ^  vdecl.declID))
				else () 
	in
	List.iter check_not_void globals;

	let rec get_variable_decl (symtab : symbol_table) (id : string) :vardecl =
		try List.find (fun vdecl -> vdecl.declID = id) symtab.variables
	  with
	  | Not_found -> 
	  	(match symtab.parent with
	  		| Some parent -> get_variable_decl parent id 
	  		| _ -> raise Not_found) in
	let get_variable_type (symtab : symbol_table) (id : string) :datatype =
		let vdecl = get_variable_decl symtab id
	  in vdecl.declTyp in
	let check_variable_declaration (env : env) (decl: vardecl) = 
		print_endline("checking var decls");

		(* A variable cannot have type void. *)
		let check_not_void_var (decl : vardecl) = 
			print_endline("checking void vars");
			let var_typ = (fun v -> decl.declTyp) decl in
					if var_typ = Datatype(Void) then raise (Failure ("illegal void variable " ^ decl.declID))
					else ()
		in 
		ignore(check_not_void_var (decl));

		(* Ensure that declInit and declType match using check_expr *)
		(try
			let _ = 
				(* Error out if local variable with same name already exists. *)
				List.find 
					(fun vdecl -> vdecl.declID = decl.declID) env.symtab.variables
			in raise (Failure ("Duplicate variable " ^ decl.declID))
		with
		| Not_found -> 
			(* TODO: use same symbol table as symbol table from arg *)
			let new_symbol_table = 
				{
					(env.symtab)
					with 
					variables = decl :: env.symtab.variables;
				} in
			let new_env = { (env) with symtab = new_symbol_table; }
			and vdecl = 
				{
					declTyp = decl.declTyp;
					declID = decl.declID;
					declInit = decl.declInit;
				}
			in (new_env, vdecl))
	in	

	(* Check arguments *)
	let check_argdecl (env : env) (adecl : argdecl) = 
		print_endline("checking arg decl");

		(* An argument cannot have type void. *)
		let check_not_void_arg (adecl : argdecl) = 
			print_endline("checking void args");
			let arg_typ = (fun a -> a.argdeclType) adecl in
					if arg_typ = Datatype(Void) then raise (Failure ("illegal void arg"))
					else ()
		in 
		ignore(check_not_void_arg (adecl));

		(try
			let _ = 
				(* Error out if local variable with same name already exists. *)
				List.find 
					(fun argdecl -> argdecl.argdeclID = adecl.argdeclID) env.symtab.args
			in raise (Failure ("Duplicate variable " ^ adecl.argdeclID))
		with
		| Not_found -> 
			let new_symbol_table = 
				{
					(env.symtab)
					with 
					args = adecl :: env.symtab.args;
				} in
			let new_env = { (env) with symtab = new_symbol_table; }
			and arg = 
				{
					argdeclType = adecl.argdeclType;
					argdeclID = adecl.argdeclID;
				}
			in (new_env, adecl))
	in

	(*let rec check_binop e1 e2 binop env = 
		print_endline("checking binop");
		let checked_e1 = check_expr e1 in

		Datatype(Int)
  in*)

	let rec check_expr (env : env) (expr : expr) = 
		match expr with 
			IntLit i -> print_endline("int"); Datatype(Int)
		| Id s -> print_endline("id"); 
			let t =
				(try get_variable_type env.symtab s 
				with | Not_found -> raise (Failure ("undeclared identifier " ^ s))
				) in 
			Datatype(Int) (* Get type of var*)
		| Binop (e1, op, e2) -> print_endline("expr is binop");
			let e1 = check_expr env e1 
			and e2 = check_expr env e2 in
			match op with 
			| Asn -> print_endline("asn"); Datatype(Int)
	in



	let check_stmt (env : env) (stmt : stmt) :(env * stmt) = 
		print_endline("checking stmt");
		match stmt with 
			Expr e -> ignore(check_expr env e); (env, stmt) (* Expression cannot mutate the environment. *)
		| Decl vdecl -> (* Return new env*)
			let (new_env, vdecl) = check_variable_declaration env vdecl
			in (new_env, stmt) in

	(* Each statement takes the environment updated from the previous statement. *)
	let check_stmt_list (env : env) ( slist : stmt list ) :(env * stmt list) = 
		print_endline("checking stmt list");
		let(new_env, stmts) = 
			List.fold_left (fun acc stmt ->
				let (nenv, s) = check_stmt (fst acc) stmt
			  in (nenv, (s :: (snd acc)))) (env, []) slist
		in (new_env, List.rev stmts) 
	in

	(* Check function declaration and return new environment. *)
	let check_function_declaration (env : env) (fdecl : funcdecl) : (env * funcdecl) =
		print_endline("checking func decl");
		(* Get the types of the function's arguments. *)
		let a_types = List.map (fun adecl -> adecl.argdeclType) fdecl.args in
		(* Make a function entry for the function. *)
		let func_entry = 
			{
				name = fdecl.fname;
				arg_types = a_types;
				return_type = fdecl.typ;
			} in
		let new_funcs = func_entry :: env.funcs in
		(* Make a new symbol table for the function scope. *)
		let new_symbol_table = 
			{
				parent = Some env.symtab;
				args = [];
				variables = [];
			} in
		(* Add the function to the environment 
		For now, the symbol table and return type have empty local scope. *)
		let new_env = 
		{
			(env)
			with
			symtab = new_symbol_table;
			funcs =  new_funcs;
			return_type = Some fdecl.typ;
		} in
		(* Add the args to the function scope. *)
		let (env_with_args, argdecl_list) = 
			List.fold_left (fun acc argdecl ->
				let (nenv, arg) = check_argdecl (fst acc) argdecl 
				in (nenv, (arg :: (snd acc)))) (new_env, []) fdecl.args in
		(* No need to keep track of environment outside the scope of the function. *)
		let (_, func_body) = 
			check_stmt_list env_with_args fdecl.body in 
		let func_body = func_body in
		(* Return the environment with this added function. *)
		({ (env) with funcs = new_funcs; }, fdecl) 
  	in


	(* Establish initial environment *)
	let env = 
		{
			symtab = { parent = None; variables = []; args = []; };
			funcs = []; (*built-in *)
			return_type = None;
		} in

	(* Add global variables to the environment. *)
	let check_global_var (env : env) (vdecl : vardecl) = 
		print_endline("checking global vars");
		(try
			let _ =	
				(* Error out if global variable with same name already exists. *)
				List.find 
					(fun v -> v.declID = vdecl.declID) env.symtab.variables
			in raise (Failure ("Duplicate variable " ^ vdecl.declID))
		with
			| Not_found -> 
				let new_symbol_table = 
					{
						(env.symtab)
						with 
						variables = vdecl :: env.symtab.variables;
					} in
				let new_env = { (env) with symtab = new_symbol_table; }
				and vardecl = 
					{
						declTyp = vdecl.declTyp;
						declID = vdecl.declID;
						declInit = vdecl.declInit;
					}
				in (new_env, vardecl))
	in

	let(new_env, vars) = 
		List.fold_left (fun acc v ->
			let (nenv, v) = check_global_var (fst acc) v
			in (nenv, (v :: (snd acc)))) (env, []) globals 
	in 

	let (_, fdecl_list) = 
		List.fold_left (fun acc fdecl ->
			let (new_env, f) = check_function_declaration (fst acc) fdecl
			in (new_env, (f :: (snd acc)))) (env, []) functions
	in fdecl_list;

	let check_function functions =  
		print_endline("checking functions");
		



			(* A program is made up of global vars and function decls. Global vars will be tracked in a separate list.
			We have a tuple, acc accumulator of environment and function decls,
			because only function decls can modify the environment.
			 *)

		(* Return list of functions after checking functions. *)
		functions in
	  
		(*ignore(func_tuple functions);*)

		(* After semantically checking, we return the program -
		a tuple of a list of globals and a list of functions. *)
		(globals, functions);

		(*in List.iter check_function functions*)

	(*(* Make a map of global variables *)
	let global_vars = 
		let global_var map (vdecl : A.vardecl) =
			let name = vdecl.declID in
			let typ = vdecl.declTyp in
		 	StringMap.add name typ map in 
		List.fold_left global_var StringMap.empty globals in

	(* Raise exception if given list has a duplicate *)
	
	(* There may not be duplicate variable names. *)
	let report_duplicate_var exceptf globals =
		(* Get the names of the globals *)
		let global_names = List.map (fun v -> v.declID) globals in
			let rec helper = function	
					n1 :: n2 :: _ when n1 = n2 -> raise (Failure (exceptf n1))
				| _ :: t -> helper t
				| [] -> ()
			in helper (List.sort compare global_names)
	in

	(* There may not be duplicate function names. *)
	let report_duplicate_func exceptf globals =
		(* Get the names of the globals *)
		let global_names = List.map (fun f -> f.fname) globals in
			let rec helper = function	
					n1 :: n2 :: _ when n1 = n2 -> raise (Failure (exceptf n1))
				| _ :: t -> helper t
				| [] -> ()
			in helper (List.sort compare global_names)
	in

	(* There may not be duplicate arg names. *)
	let report_duplicate_arg exceptf args =
		(* Get the names of the args *)
		let arg_names = List.map (fun a -> a.argdeclID) args in
			let rec helper = function	
					n1 :: n2 :: _ when n1 = n2 -> raise (Failure (exceptf n1))
				| _ :: t -> helper t
				| [] -> ()
			in helper (List.sort compare arg_names)
	in

	(* A global variable cannot have type void. *)
	let check_not_void (vdecl : vardecl) = 
		(* Get the types of the globals *)
		let global_typ = (fun v -> v.declTyp) vdecl in
				if global_typ = Datatype(Void) then raise (Failure ("illegal var"))
				else () 
	in

	(* An argument cannot have type void. *)
	let check_not_void_arg (adecl : argdecl) = 
		let arg_typ = (fun a -> a.argdeclType) adecl in
				if arg_typ = Datatype(Void) then raise (Failure ("illegal void arg"))
				else ()
	in

	(* Check assignment - type error *)
	let check_assign lval_type rval_type err = 
			if lval_type == rval_type then lval_type 
			else raise err 
	in 

	(**** Check global vars ****)

	List.iter check_not_void globals;

	report_duplicate_var (fun n -> "duplicate global " ^ n) globals;

	(**** Check functions ****)
 
	if List.mem "print" (List.map (fun fd -> fd.fname) functions)
  	then raise (Failure ("function print may not be defined")) else ();

	report_duplicate_func (fun n -> "duplicate function " ^ n) functions;

	(* Function declaration for named function. *)
	(* TODO: Modify when we write these function in llvm. *)
	let built_in_decls =  StringMap.add "print"
     { typ = Datatype(Void); fname = "print"; args = [{argdeclType = Datatype(Int); argdeclID = "x"}];
       body = [] } (StringMap.singleton "printb"
     { typ = Datatype(Void); fname = "printb"; args = [{argdeclType = Datatype(Bool); argdeclID = "x"}];
       body = [] })
   in

  let function_decls = List.fold_left (fun map fd -> StringMap.add fd.fname fd map)
                         built_in_decls functions
  in

  let function_decl s = try StringMap.find s function_decls
       with Not_found -> raise (Failure ("unrecognized function " ^ s))
  in

  let _ = function_decl "main" in (* Ensure "main" is defined. *)

	let check_function func env =
		List.iter check_not_void_arg func.args;

		report_duplicate_arg (fun n -> "duplicate argument " ^ n) func.args;

		let local_vars = StringMap.empty in

		let add_arg map (adecl: A.argdecl) =
			let name = adecl.argdeclID in
			let typ = adecl.argdeclType in
			StringMap.add name typ map 
		in
		let add_local map (vdecl: A.vardecl) = 
			let name = vdecl.declID in
			let typ = vdecl.declTyp in
			StringMap.add name typ map
		in

		(* Add function arguments to local_vars map. *)
		let local_vars = List.fold_left add_arg local_vars func.args in

		let type_of_var v =
			print_endline("decl?");
			try StringMap.find v local_vars
			with Not_found -> raise (Failure ("undeclared identifier " ^ v))
		in
		
		let rec binop typed_e1 op typed_e2 = 
			check_assign typed_e1 typed_e2 (Failure ("illegal assignment"))
		in

		let check_local_vardecl vdecl map = 
			let local_vars = add_local map vdecl in

      let init_expr = vdecl.declInit in
      match init_expr with
        A.Noexpr      -> local_vars
      | e             -> local_vars
		in

		(* Return the type of an expression or throw exception. *)
		let rec expr = function
				IntLit _ -> Datatype(Int)
			| DoubleLit _ -> Datatype(Double)
			| CharLit _ -> Datatype(Char) 
			| StrLit _ -> Datatype(String)
			| BoolLit _ -> Datatype(Bool)
			| Id t -> type_of_var t
			| Binop (e1, op, e2) -> 
					let checked_e1 = expr e1
					and checked_e2 = expr e2
					in binop checked_e1 op checked_e2
		in

		let rec stmt = function
				Expr e -> ignore (expr e) ; local_vars
			| Decl vardecl -> 
				(*let local_vars = check_local_vardecl vardecl map
				in local_vars*)check_local_vardecl vardecl local_vars ; local_vars
			|	Block stmtlst -> let rec check_block = function
						[Return _ as s] -> stmt s
					| Return _ :: _ -> raise (Failure "nothing may follow a return") 
					| Block sl :: ss -> check_block (sl @ ss) 
					| s :: ss -> stmt s ; check_block ss 
					| [] -> local_vars
				in check_block stmtlst

		in

		(* Account for local var decls being part of func body stmt *)
		let _ = stmt (Block func.body) in ()


	in
	List.iter check_function functions*)