(***********************************************************************)
(*                             OCamldoc                                *)
(*                                                                     *)
(*            Maxence Guesdon, projet Cristal, INRIA Rocquencourt      *)
(*                                                                     *)
(*  Copyright 2001 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the Q Public License version 1.0.               *)
(*                                                                     *)
(***********************************************************************)


(** Analysis of implementation files. *)
open Misc
open Asttypes
open Types
open Typedtree

let print_DEBUG3 s = print_string s ; print_newline ();;
let print_DEBUG s = print_string s ; print_newline ();;

type typedtree = (Typedtree.structure * Typedtree.module_coercion)

module Name = Odoc_name
open Odoc_parameter
open Odoc_value
open Odoc_type
open Odoc_exception
open Odoc_class
open Odoc_module
open Odoc_types

(** This variable contains the regular expression representing a blank.*)
let blank = "[ \010\013\009\012']"
(** This variable contains the regular expression representing a blank but not a '\n'.*)
let simple_blank = "[ \013\009\012]"


(** This module is used to search for structure items by name in a Typedtree.structure. 
   One function creates two hash tables, which can then be used to search for elements.
   Class elements do not use tables.
*)
module Typedtree_search =
  struct
    type ele = 
      |	M of string
      |	MT of string
      |	T of string
      |	C of string
      |	CT of string
      |	E of string
      |	ER of string
      |	P of string
      |	IM of string

    type tab = (ele, Typedtree.structure_item) Hashtbl.t
    type tab_values = (Odoc_module.Name.t, Typedtree.pattern * Typedtree.expression) Hashtbl.t

    let iter_val_pattern = function
      | Typedtree.Tpat_any -> None
      | Typedtree.Tpat_var name -> Some (Name.from_ident name)
      | Typedtree.Tpat_tuple _ -> None (* A VOIR quand on traitera les tuples *)
      | _ -> None

    let add_to_hashes table table_values tt = 
      match tt with
      | Typedtree.Tstr_module (ident, _) -> 
	  Hashtbl.add table (M (Name.from_ident ident)) tt
      |	Typedtree.Tstr_modtype (ident, _) -> 
	  Hashtbl.add table (MT (Name.from_ident ident)) tt
      |	Typedtree.Tstr_exception (ident, _) ->
	  Hashtbl.add table (E (Name.from_ident ident)) tt
      |	Typedtree.Tstr_exn_rebind (ident, _) ->
	  Hashtbl.add table (ER (Name.from_ident ident)) tt
      |	Typedtree.Tstr_type ident_type_decl_list ->
	  List.iter
	    (fun (id, e) -> 
	      Hashtbl.add table (T (Name.from_ident id)) 
		(Typedtree.Tstr_type [(id,e)]))
	    ident_type_decl_list
      |	Typedtree.Tstr_class info_list ->
	  List.iter
	    (fun ((id,_,_,_) as ci) -> 
	      Hashtbl.add table (C (Name.from_ident id))
		(Typedtree.Tstr_class [ci]))
	    info_list
      |	Typedtree.Tstr_cltype info_list ->
	  List.iter
	    (fun ((id,_) as ci) -> 
	      Hashtbl.add table
		(CT (Name.from_ident id))
		(Typedtree.Tstr_cltype [ci]))
	    info_list
      |	Typedtree.Tstr_value (_, pat_exp_list) ->
	  List.iter
	    (fun (pat,exp) ->
	      match iter_val_pattern pat.Typedtree.pat_desc with
		None -> ()
	      |	Some n -> Hashtbl.add table_values n (pat,exp)
	    )
	    pat_exp_list
      |	Typedtree.Tstr_primitive (ident, _) ->
	  Hashtbl.add table (P (Name.from_ident ident)) tt
      |	Typedtree.Tstr_open _ -> ()
      |	Typedtree.Tstr_include _ -> ()
      |	Typedtree.Tstr_eval _ -> ()

    let tables typedtree =
      let t = Hashtbl.create 13 in
      let t_values = Hashtbl.create 13 in
      List.iter (add_to_hashes t t_values) typedtree;
      (t, t_values)

    let search_module table name =
      match Hashtbl.find table (M name) with
	(Typedtree.Tstr_module (_, module_expr)) -> module_expr
      |	_ -> assert false

    let search_module_type table name =
      match Hashtbl.find table (MT name) with
      | (Typedtree.Tstr_modtype (_, module_type)) -> module_type
      | _ -> assert false

    let search_exception table name =
      match Hashtbl.find table (E name) with
      | (Typedtree.Tstr_exception (_, excep_decl)) -> excep_decl
      | _ -> assert false

    let search_exception_rebind table name =
      match Hashtbl.find table (ER name) with
      | (Typedtree.Tstr_exn_rebind (_, p)) -> p
      |	_ -> assert false

    let search_type_declaration table name =
      match Hashtbl.find table (T name) with
      | (Typedtree.Tstr_type [(_,decl)]) -> decl
      |	_ -> assert false

    let search_class_exp table name =
      match Hashtbl.find table (C name) with
      | (Typedtree.Tstr_class [(_,_,_,ce)]) ->
	  (
	   try
	     let type_decl = search_type_declaration table name in
	     (ce, type_decl.Types.type_params)
	   with
	     Not_found ->
	       (ce, [])
	  )
      |	_ -> assert false

    let search_class_type_declaration table name =
      match Hashtbl.find table (CT name) with
      | (Typedtree.Tstr_cltype [(_,cltype_decl)]) -> cltype_decl
      |	_ -> assert false

    let search_value table name = Hashtbl.find table name 

    let search_primitive table name =
      match Hashtbl.find table (P name) with
	Tstr_primitive (ident, val_desc) -> val_desc.Types.val_type
      |	_ -> assert false

    let get_nth_inherit_class_expr cls n =
      let rec iter cpt = function
	| [] ->
	    raise Not_found
	| Typedtree.Cf_inher (clexp, _, _) :: q ->
	    if n = cpt then clexp else iter (cpt+1) q
	| _ :: q ->
	    iter cpt q
      in
      iter 0 cls.Typedtree.cl_field

    let search_attribute_type cls name =
      let rec iter = function
	| [] ->
	    raise Not_found
	| Typedtree.Cf_val (_, ident, exp) :: q 
	  when Name.from_ident ident = name ->
	    exp.Typedtree.exp_type
	| _ :: q ->
	    iter q
      in
      iter cls.Typedtree.cl_field

   let search_method_expression cls name =
      let rec iter = function
	| [] ->
	    raise Not_found
	| Typedtree.Cf_meth (label, exp) :: q when label = name ->
	    exp
	| _ :: q ->
	    iter q
      in
      iter cls.Typedtree.cl_field
  end

module Analyser = 
  functor (My_ir : Odoc_sig.Info_retriever) ->

  struct
    module Sig = Odoc_sig.Analyser (My_ir)

    (** This variable is used to load a file as a string and retrieve characters from it.*)
    let file = Sig.file

    (** The name of the analysed file. *)
    let file_name = Sig.file_name

    (** This function takes two indexes (start and end) and return the string
       corresponding to the indexes in the file global variable. The function
       prepare_file must have been called to fill the file global variable.*)
    let get_string_of_file = Sig.get_string_of_file

    (** This function loads the given file in the file global variable.
       and sets file_name.*)
    let prepare_file = Sig.prepare_file

    (** The function used to get the comments in a class. *)
    let get_comments_in_class = Sig.get_comments_in_class

    (** The function used to get the comments in a module. *)
    let get_comments_in_module = Sig.get_comments_in_module

    (** This function takes a parameter pattern and builds the 
       corresponding [parameter] structure. The f_desc function
       is used to retrieve a parameter description, if any, from
       a parameter name.
    *)
    let tt_param_info_from_pattern env f_desc pat =
      let rec iter_pattern pat =
	match pat.pat_desc with
	  Typedtree.Tpat_var ident ->
	    let name = Name.from_ident ident in
	    Simple_name { sn_name = name ;
			  sn_text = f_desc name ;
			  sn_type = Odoc_env.subst_type env pat.pat_type
			} 
	      
	| Typedtree.Tpat_alias (pat, _) ->
	    iter_pattern pat

	| Typedtree.Tpat_tuple patlist ->
	    Tuple
	      (List.map iter_pattern patlist,
	       Odoc_env.subst_type env pat.pat_type)
	      
	| Typedtree.Tpat_construct (cons_desc, _) when 
	    (* we give a name to the parameter only if it unit *)
	    (match cons_desc.cstr_res.desc with
	      Tconstr (p, _, _) ->
		Path.same p Predef.path_unit 
	    | _ ->
		false)
	  ->
	    (* a () argument, it never has description *)
	    Simple_name { sn_name = "()" ;
			  sn_text = None ;
			  sn_type = Odoc_env.subst_type env pat.pat_type
			} 

	| _ ->
            (* implicit pattern matching -> anonymous parameter *)
	    Simple_name { sn_name = "()" ;
			  sn_text = None ;
			  sn_type = Odoc_env.subst_type env pat.pat_type
			} 
      in
      iter_pattern pat 

    (** Analysis of the parameter of a function. Return a list of t_parameter created from
       the (pattern, expression) structures encountered. *)
    let rec tt_analyse_function_parameters env current_comment_opt pat_exp_list =
      match pat_exp_list with
	[] ->
	  (* This case means we have a 'function' without pattern, that's impossible *)
	  raise (Failure "tt_analyse_function_parameters: 'function' without pattern")

      |	(pattern_param, exp) :: second_ele :: q ->
          (* implicit pattern matching -> anonymous parameter and no more parameter *)
	  (* A VOIR : le label ? *)
	  let parameter = Odoc_parameter.Tuple ([], Odoc_env.subst_type env pattern_param.pat_type) in
	  [ parameter ]

      | (pattern_param, func_body) :: [] ->
	  let parameter = 
	    tt_param_info_from_pattern 
	      env
	      (Odoc_parameter.desc_from_info_opt current_comment_opt) 
	      pattern_param

	  in
         (* For optional parameters with a default value, a special treatment is required *)
         (* we look if the name of the parameter we just add is "*opt*", which means
	    that there is a let param_name = ... in ... just right now *)
	  let (p, next_exp) = 
	    match parameter with
	      Simple_name { sn_name = "*opt*" } ->
		(
		 (
		  match func_body.exp_desc with
		    Typedtree.Texp_let (_, ({pat_desc = Typedtree.Tpat_var id } , exp) :: _, func_body2) ->
		      let name = Name.from_ident id in
		      let new_param = Simple_name 
			  { sn_name = name ;
			    sn_text = Odoc_parameter.desc_from_info_opt current_comment_opt name ;
			    sn_type = Odoc_env.subst_type env exp.exp_type
			  }
		      in
		      (new_param, func_body2)
		  | _ ->
		      print_DEBUG3 "Pas le bon filtre pour le param�tre optionnel avec valeur par d�faut.";
		      (parameter, func_body)
		 )
		)
	    | _ ->
		(parameter, func_body)
	  in
         (* continue if the body is still a function *)
	  match next_exp.exp_desc with
	    Texp_function (pat_exp_list, _) ->
	      p :: (tt_analyse_function_parameters env current_comment_opt pat_exp_list)
	  | _ ->
              (* something else ; no more parameter *)
	      [ p ]

     (** Analysis of a Tstr_value from the typedtree. Create and return a list of [t_value].
	@raise Failure if an error occurs.*)
     let tt_analyse_value env current_module_name comment_opt loc pat_exp rec_flag =
       let (pat, exp) = pat_exp in
       match (pat.pat_desc, exp.exp_desc) with
	 (Typedtree.Tpat_var ident, Typedtree.Texp_function (pat_exp_list2, partial)) ->
           (* a new function is defined *)
	   let name_pre = Name.from_ident ident in
	   let name = Name.parens_if_infix name_pre in
	   let complete_name = Name.concat current_module_name name in
 	   (* create the value *)
	   let new_value = {
	     val_name = complete_name ;
	     val_info = comment_opt ;
	     val_type = Odoc_env.subst_type env pat.Typedtree.pat_type ;
	     val_recursive = rec_flag = Asttypes.Recursive ;
	     val_parameters = tt_analyse_function_parameters env comment_opt pat_exp_list2 ;
	     val_code = Some (get_string_of_file loc.Location.loc_start loc.Location.loc_end) ;
	     val_loc = { loc_impl = Some (!file_name, loc.Location.loc_start) ; loc_inter = None } ;
	   }	
	   in
	   [ new_value ]
	     
       | (Typedtree.Tpat_var ident, _) ->
	   (* a new value is defined *)	    
	   let name_pre = Name.from_ident ident in
	   let name = Name.parens_if_infix name_pre in
	   let complete_name = Name.concat current_module_name name in
	   let new_value = {
	     val_name = complete_name ;
	     val_info = comment_opt ;
	     val_type = Odoc_env.subst_type env pat.Typedtree.pat_type ;
	     val_recursive = rec_flag = Asttypes.Recursive ;
	     val_parameters = [] ;
	     val_code = Some (get_string_of_file loc.Location.loc_start loc.Location.loc_end) ;
	     val_loc = { loc_impl = Some (!file_name, loc.Location.loc_start) ; loc_inter = None } ;
	   }	
	   in
	   [ new_value ]
	     
       | (Typedtree.Tpat_tuple lpat, _) ->
	   (* new identifiers are defined *)
	   (* A VOIR : by now we don't accept to have global variables defined in tuples *)
	   []
	     
       | _ ->
	   (* something else, we don't care ? A VOIR *)
	   []

    (** This function takes a Typedtree.class_expr and returns a string which can stand for the class name.
       The name can be "object ... end" if the class expression is not an ident or a class constraint or a class apply. *)
    let rec tt_name_of_class_expr clexp =
      match clexp.Typedtree.cl_desc with
	Typedtree.Tclass_ident p -> Name.from_path p
      |	Typedtree.Tclass_constraint (class_expr, _, _, _)
      |	Typedtree.Tclass_apply (class_expr, _) -> tt_name_of_class_expr class_expr
(*
      |	Typedtree.Tclass_fun (_, _, class_expr, _) -> tt_name_of_class_expr class_expr
      |	Typedtree.Tclass_let (_,_,_, class_expr) -> tt_name_of_class_expr class_expr
*)
      |	 _ -> Odoc_messages.object_end

    (** Analysis of a method expression to get the method parameters. 
       @param first indicates if we're analysing the method for
       the first time ; in that case we must not keep the first parameter,
       which is "self-*", the object itself.
    *)
    let rec tt_analyse_method_expression env current_method_name comment_opt ?(first=true) exp =
      match exp.Typedtree.exp_desc with
	Typedtree.Texp_function (pat_exp_list, _) ->
	  (
	   match pat_exp_list with
	     [] ->
	       (* it is not a function since there are no parameters *)
	       (* we can't get here normally *)
	       raise (Failure (Odoc_messages.bad_tree^" "^(Odoc_messages.method_without_param current_method_name)))
	   | l ->
	       match l with
		 [] ->
		   (* cas impossible, on l'a filtr� avant *)
		   assert false
	       | (pattern_param, exp) :: second_ele :: q ->
                   (* implicit pattern matching -> anonymous parameter *)
		   (* Note : We can't match this pattern if it is the first call to the function. *)
		   let new_param = Simple_name
		       { sn_name = "??" ; sn_text =  None; 
			 sn_type = Odoc_env.subst_type env pattern_param.Typedtree.pat_type }
		   in
		   [ new_param ]
		     
	       | (pattern_param, body) :: [] ->
		   (* if this is the first call to the function, this is the first parameter and we skip it *)
		   if not first then
		     (
		      let parameter = 
			tt_param_info_from_pattern
			  env
			  (Odoc_parameter.desc_from_info_opt comment_opt) 
			  pattern_param
		      in
                      (* For optional parameters with a default value, a special treatment is required. *)
                      (* We look if the name of the parameter we just add is "*opt*", which means
			 that there is a let param_name = ... in ... just right now. *)
		      let (current_param, next_exp) = 
			match parameter with
			  Simple_name { sn_name = "*opt*"} ->
			    (
			     (
			      match body.exp_desc with
				Typedtree.Texp_let (_, ({pat_desc = Typedtree.Tpat_var id } , exp) :: _, body2) ->
				  let name = Name.from_ident id in
				  let new_param = Simple_name 
				      { sn_name = name ;
					sn_text = Odoc_parameter.desc_from_info_opt comment_opt name ;
					sn_type = Odoc_env.subst_type env exp.Typedtree.exp_type ; 
				      }
				  in
				  (new_param, body2)
			      | _ ->
				  print_DEBUG3 "Pas le bon filtre pour le param�tre optionnel avec valeur par d�faut.";
				  (parameter, body)
			     )
			    )
			| _ ->
  	                    (* no *opt* parameter, we add the parameter then continue *)
			    (parameter, body)
		      in
		      current_param :: (tt_analyse_method_expression env current_method_name comment_opt ~first: false next_exp)
		     )
		   else
		     tt_analyse_method_expression env current_method_name comment_opt ~first: false body
	  )
      | _ ->
	  (* no more parameter *)
	  []

    (** Analysis of a [Parsetree.class_struture] and a [Typedtree.class_structure] to get a couple 
       (inherited classes, class elements). *)
    let analyse_class_structure env current_class_name tt_class_sig last_pos pos_limit p_cls tt_cls =
      let rec iter acc_inher acc_fields last_pos = function
	| [] -> 
	    let s = get_string_of_file last_pos pos_limit in
	    let (_, ele_coms) = My_ir.all_special !file_name s in
	    let ele_comments =
	      List.fold_left
		(fun acc -> fun sc ->
		  match sc.Odoc_types.i_desc with
		    None ->
		      acc
		  | Some t ->
		      acc @ [Class_comment t])
		[]
		ele_coms
	    in
	    (acc_inher, acc_fields @ ele_comments)

	| (Parsetree.Pcf_inher (p_clexp, _)) :: q  ->
	    let tt_clexp =
	      let n = List.length acc_inher in
	      try Typedtree_search.get_nth_inherit_class_expr tt_cls n
	      with Not_found -> raise (Failure (Odoc_messages.inherit_classexp_not_found_in_typedtree n))
	    in
	    let (info_opt, ele_comments) = get_comments_in_class last_pos p_clexp.Parsetree.pcl_loc.Location.loc_start in
	    let text_opt = match info_opt with None -> None | Some i -> i.Odoc_types.i_desc in
	    let name = tt_name_of_class_expr tt_clexp in
	    let inher = { ic_name = Odoc_env.full_class_or_class_type_name env name ; ic_class = None ; ic_text = text_opt }  in
	    iter (acc_inher @ [ inher ]) (acc_fields @ ele_comments)
	      p_clexp.Parsetree.pcl_loc.Location.loc_end
	      q

	| (Parsetree.Pcf_val (label, mutable_flag, expression, loc)) :: q ->
	    let complete_name = Name.concat current_class_name label in
	    let (info_opt, ele_comments) = get_comments_in_class last_pos loc.Location.loc_start in
	    let type_exp =
	      try Typedtree_search.search_attribute_type tt_cls label
	      with Not_found -> raise (Failure (Odoc_messages.attribute_not_found_in_typedtree complete_name))
	    in
	    let att =
	      {
		att_value = { val_name = complete_name ; 
			      val_info = info_opt ;
			      val_type = Odoc_env.subst_type env type_exp ;
			      val_recursive = false ;
			      val_parameters = [] ; 
			      val_code = Some (get_string_of_file loc.Location.loc_start loc.Location.loc_end) ;
			      val_loc = { loc_impl = Some (!file_name, loc.Location.loc_start) ; loc_inter = None } ;
			    } ;
		att_mutable = mutable_flag = Asttypes.Mutable ;
	      }	
	    in
	    iter acc_inher (acc_fields @ ele_comments @ [ Class_attribute att ]) loc.Location.loc_end q
      
	| (Parsetree.Pcf_virt  (label, private_flag, _, loc)) :: q ->
	    let complete_name = Name.concat current_class_name label in
	    let (info_opt, ele_comments) = get_comments_in_class last_pos loc.Location.loc_start in
	    let met_type = 
	      try Odoc_sig.Signature_search.search_method_type label tt_class_sig 
	      with Not_found -> raise (Failure (Odoc_messages.method_type_not_found current_class_name label))
	    in
	    let real_type =
	      match met_type.Types.desc with
		Tarrow (_, _, t, _) ->
		  t
	      |  _ ->
     	        (* ?!? : not an arrow type ! return the original type *)
		  met_type
	    in
	    let met = 
	      {
		met_value = { val_name = complete_name ;
			      val_info = info_opt ;
			      val_type = Odoc_env.subst_type env real_type ;
			      val_recursive = false ;
			      val_parameters = [] ;
			      val_code = Some (get_string_of_file loc.Location.loc_start loc.Location.loc_end) ;
			      val_loc = { loc_impl = Some (!file_name, loc.Location.loc_start) ; loc_inter = None } ;
			    } ;
		met_private = private_flag = Asttypes.Private ;
		met_virtual = true ;
	      }	
	    in
      	    (* update the parameter description *)
	    Odoc_value.update_value_parameters_text met.met_value;

	    iter acc_inher (acc_fields @ ele_comments @ [ Class_method met ]) loc.Location.loc_end q

	| (Parsetree.Pcf_meth  (label, private_flag, _, loc)) :: q ->
	    let complete_name = Name.concat current_class_name label in
	    let (info_opt, ele_comments) = get_comments_in_class last_pos loc.Location.loc_start in
	    let exp = 
	      try Typedtree_search.search_method_expression tt_cls label
	      with Not_found -> raise (Failure (Odoc_messages.method_not_found_in_typedtree complete_name))
	    in
	    let real_type =
	      match exp.exp_type.desc with
		Tarrow (_, _, t,_) ->
		  t
	      |  _ ->
     	        (* ?!? : not an arrow type ! return the original type *)
		  exp.Typedtree.exp_type
	    in
	    let met = 
	      {
		met_value = { val_name = complete_name ;
			      val_info = info_opt ;
			      val_type = Odoc_env.subst_type env real_type ;
			      val_recursive = false ;
			      val_parameters = tt_analyse_method_expression env complete_name info_opt exp ;
			      val_code = Some (get_string_of_file loc.Location.loc_start loc.Location.loc_end) ;
			      val_loc = { loc_impl = Some (!file_name, loc.Location.loc_start) ; loc_inter = None } ;
			    } ;
		met_private = private_flag = Asttypes.Private ;
		met_virtual = false ;
	      }	
	    in
      	    (* update the parameter description *)
	    Odoc_value.update_value_parameters_text met.met_value;

	    iter acc_inher (acc_fields @ ele_comments @ [ Class_method met ]) loc.Location.loc_end q
	    
	| Parsetree.Pcf_cstr (_, _, loc) :: q ->
	    (* don't give a $*%@ ! *)
	    iter acc_inher acc_fields loc.Location.loc_end q

	| Parsetree.Pcf_let (_, _, loc) :: q ->
	    (* don't give a $*%@ ! *)
	    iter acc_inher acc_fields loc.Location.loc_end q

	| (Parsetree.Pcf_init exp) :: q ->
	    iter acc_inher acc_fields exp.Parsetree.pexp_loc.Location.loc_end q
      in
      iter [] [] last_pos (snd p_cls)
	      
    (** Analysis of a [Parsetree.class_expr] and a [Typedtree.class_expr] to get a a couple (class parameters, class kind). *)
    let rec analyse_class_kind env current_class_name comment_opt last_pos p_class_expr tt_class_exp =
      match (p_class_expr.Parsetree.pcl_desc, tt_class_exp.Typedtree.cl_desc) with
	(Parsetree.Pcl_constr (lid, _), tt_class_exp_desc ) -> 
	  let name = 
	    match tt_class_exp_desc with
	      Typedtree.Tclass_ident p -> Name.from_path p 
	    | _ ->
		(* we try to get the name from the environment. *)
                (* A VOIR : dommage qu'on n'ait pas un Tclass_ident :-( m�me quand on a class tutu = toto *)
		Name.from_longident lid
	  in
	  (* On n'a pas ici les param�tres de type sous forme de Types.type_expr,
	     par contre on peut les trouver dans le class_type *)
	  let params = 
	    match tt_class_exp.Typedtree.cl_type with
	      Types.Tcty_constr (p2, type_exp_list, cltyp) ->
		(* cltyp is the class type for [type_exp_list] p *)
		type_exp_list
	    | _ ->
		[]
	  in
	  ([], 
	   Class_constr
	     {
	       cco_name = Odoc_env.full_class_name env name ;
	       cco_class = None ;
	       cco_type_parameters = List.map (Odoc_env.subst_type env) params ; 
	     } )

      | (Parsetree.Pcl_structure p_class_structure, Typedtree.Tclass_structure tt_class_structure) ->
	  (* we need the class signature to get the type of methods in analyse_class_structure *)
	  let tt_class_sig = 
	    match tt_class_exp.Typedtree.cl_type with
	      Types.Tcty_signature class_sig -> class_sig
	    | _ -> raise (Failure "analyse_class_kind: no class signature for a class structure.")
	  in
	  let (inherited_classes, class_elements) = analyse_class_structure 
	      env
	      current_class_name 
	      tt_class_sig
	      last_pos
	      p_class_expr.Parsetree.pcl_loc.Location.loc_end
	      p_class_structure
	      tt_class_structure
	  in
	  ([],
	   Class_structure (inherited_classes, class_elements) )
	    
      | (Parsetree.Pcl_fun (label, expression_opt, pattern, p_class_expr2),
	 Typedtree.Tclass_fun (pat, ident_exp_list, tt_class_expr2, partial)) ->
	   (* we check that this is not an optional parameter with
	      a default value. In this case, we look for the good parameter pattern *)
	   let (parameter, next_tt_class_exp) =
	     match pat.Typedtree.pat_desc with
	       Typedtree.Tpat_var ident when Name.from_ident ident = "*opt*" ->
		 (
		  (* there must be a Tclass_let just after *)
		  match tt_class_expr2.Typedtree.cl_desc with
		    Typedtree.Tclass_let (_, ({pat_desc = Typedtree.Tpat_var id } , exp) :: _, _, tt_class_expr3) ->
		      let name = Name.from_ident id in
		      let new_param = Simple_name
			  { sn_name = name ;
			    sn_text = Odoc_parameter.desc_from_info_opt comment_opt name ;
			    sn_type = Odoc_env.subst_type env exp.exp_type
			  }
		      in
		      (new_param, tt_class_expr3)
		 | _ ->
		     (* strange case *)
		     (* we create the parameter and add it to the class *)
		     raise (Failure "analyse_class_kind: strange case")
		 )
             | _ ->
		 (* no optional parameter with default value, we create the parameter *)
		 let new_param = 
		   tt_param_info_from_pattern
		     env
		     (Odoc_parameter.desc_from_info_opt comment_opt)
		     pat
		 in
		 (new_param, tt_class_expr2)
	   in
	   let (params, k) = analyse_class_kind env current_class_name comment_opt last_pos p_class_expr2 next_tt_class_exp in
	   (parameter :: params, k)

      | (Parsetree.Pcl_apply (p_class_expr2, _), Tclass_apply (tt_class_expr2, exp_opt_optional_list)) ->
	  let applied_name =
            (* we want an ident, or else the class applied will appear in the form object ... end,
	       because if the class applied has no name, the code is kinda ugly, isn't it ? *)
	    match tt_class_expr2.Typedtree.cl_desc with
	      Typedtree.Tclass_ident p -> Name.from_path p (* A VOIR : obtenir le nom complet *)
	    | _ -> 
                (* A VOIR : dommage qu'on n'ait pas un Tclass_ident :-( m�me quand on a class tutu = toto *)
		match p_class_expr2.Parsetree.pcl_desc with
		  Parsetree.Pcl_constr (lid, _) ->
		    (* we try to get the name from the environment. *)
		    Name.from_longident lid
		|  _ ->
		    Odoc_messages.object_end
	  in
	  let param_exps = List.fold_left
	      (fun acc -> fun (exp_opt, _) -> 
		match exp_opt with 
		  None -> acc
		| Some e -> acc @ [e])
	      []
	      exp_opt_optional_list
	  in
	  let param_types = List.map (fun e -> e.Typedtree.exp_type) param_exps in
	  let params_code = 
	    List.map 
	      (fun e -> get_string_of_file 
		  e.exp_loc.Location.loc_start
		  e.exp_loc.Location.loc_end)
	      param_exps
	  in
	  ([],
	   Class_apply
	     { capp_name = Odoc_env.full_class_name env applied_name ;
	       capp_class = None ;
	       capp_params = param_types ;
	       capp_params_code = params_code ;
	     } )

      | (Parsetree.Pcl_let (_, _, p_class_expr2), Typedtree.Tclass_let (_, _, _, tt_class_expr2)) ->
	  (* we don't care about these lets *)
	  analyse_class_kind env current_class_name comment_opt last_pos p_class_expr2 tt_class_expr2
 
      | (Parsetree.Pcl_constraint (p_class_expr2, p_class_type2), 
	 Typedtree.Tclass_constraint (tt_class_expr2, _, _, _)) ->
	  let (l, class_kind)  = analyse_class_kind env current_class_name comment_opt last_pos p_class_expr2 tt_class_expr2 in
	  (* A VOIR : analyse du class type ? on n'a pas toutes les infos. cf. Odoc_sig.analyse_class_type_kind *)
	  let class_type_kind = 
	    (*Sig.analyse_class_type_kind
	      env
	      ""
	      p_class_type2.Parsetree.pcty_loc.Location.loc_start
	      p_class_type2
	      tt_class_expr2.Typedtree.cl_type
	    *)
	    Class_type { cta_name = Odoc_messages.object_end ;
			 cta_class = None ; cta_type_parameters = [] }
	  in
	  (l, Class_constraint (class_kind, class_type_kind))

      |	_ ->
	  raise (Failure "analyse_class_kind: Parsetree and typedtree don't match.")

    (** Analysis of a [Parsetree.class_declaration] and a [Typedtree.class_expr] to return a [t_class].*)
    let analyse_class env current_module_name comment_opt p_class_decl tt_type_params tt_class_exp =
      let name = p_class_decl.Parsetree.pci_name in
      let complete_name = Name.concat current_module_name name in
      let pos_start = p_class_decl.Parsetree.pci_expr.Parsetree.pcl_loc.Location.loc_start in
      let type_parameters = tt_type_params in
      let virt = p_class_decl.Parsetree.pci_virt = Asttypes.Virtual in
      let cltype = Odoc_env.subst_class_type env tt_class_exp.Typedtree.cl_type in
      let (parameters, kind) = analyse_class_kind 
	  env
	  complete_name
	  comment_opt
	  pos_start
	  p_class_decl.Parsetree.pci_expr
	  tt_class_exp
      in
      let cl =
	{
	  cl_name = complete_name ;
	  cl_info = comment_opt ;
	  cl_type = cltype ;
	  cl_virtual = virt ;
	  cl_type_parameters = type_parameters ;
	  cl_kind = kind ;
	  cl_parameters = parameters ;
	  cl_loc = { loc_impl = Some (!file_name, pos_start) ; loc_inter = None } ;
	} 
      in
      cl

    (** Get a name from a module expression, or "struct ... end" if the module expression
       is not an ident of a constraint on an ident. *)
    let rec tt_name_from_module_expr mod_expr =
      match mod_expr.Typedtree.mod_desc with
	Typedtree.Tmod_ident p -> Name.from_path p
      | Typedtree.Tmod_constraint (m_exp, _, _) -> tt_name_from_module_expr m_exp
      | Typedtree.Tmod_structure _
      | Typedtree.Tmod_functor _ 
      | Typedtree.Tmod_apply _ ->
	  Odoc_messages.struct_end

    (** Get the list of included modules in a module structure of a typed tree. *)
    let tt_get_included_module_list tt_structure =
      let f acc item =
	match item with
	  Typedtree.Tstr_include (mod_expr, _) ->
	    acc @ [
		  { (* A VOIR : chercher dans les modules et les module types, avec quel env ? *)
		    im_name = tt_name_from_module_expr mod_expr ;
		    im_module = None ;
		  } 
		] 
	| _ ->
	    acc
      in
      List.fold_left f [] tt_structure

    (** This function takes a [module element list] of a module and replaces the "dummy" included modules with
       the ones found in typed tree structure of the module. *)
    let replace_dummy_included_modules module_elements included_modules =
      prerr_endline "replace_dummy_included_modules";
      let rec f = function
	| ([], _) ->
	    []
	| ((Element_included_module im) :: q, (im_repl :: im_q)) ->
	    (Element_included_module im_repl) :: (f (q, im_q))
	| ((Element_included_module im) :: q, []) ->
	    prerr_endline (Printf.sprintf "module %s not found (empty list)" im.im_name);
	    (Element_included_module im) :: q
	| (ele :: q, l) ->
	    ele :: (f (q, l))
      in
      f (module_elements, included_modules)

    (** Analysis of a parse tree structure with a typed tree, to return module elements.*)
    let rec analyse_structure env current_module_name last_pos pos_limit parsetree typedtree = 
      print_DEBUG "Odoc_ast:analyse_struture";
      let (table, table_values) = Typedtree_search.tables typedtree in
      let rec iter env last_pos = function
	  [] -> 
	    let s = get_string_of_file last_pos pos_limit in
	    let (_, ele_coms) = My_ir.all_special !file_name s in
	    let ele_comments =
	      List.fold_left
		(fun acc -> fun sc ->
		  match sc.Odoc_types.i_desc with
		    None ->
		      acc
		  | Some t ->
		      acc @ [Element_module_comment t])
		[]
		ele_coms
	    in
	    ele_comments
	| item :: q -> 
	    let (comment_opt, ele_comments) = 
	      get_comments_in_module last_pos item.Parsetree.pstr_loc.Location.loc_start 
	    in
	    let pos_limit2 =
	      match q with
		[] -> pos_limit
	      |	item2 :: _ -> item2.Parsetree.pstr_loc.Location.loc_start
	    in
	    let (maybe_more, new_env, elements) = analyse_structure_item
		env
		current_module_name
		item.Parsetree.pstr_loc
		pos_limit2
		comment_opt
		item.Parsetree.pstr_desc
		typedtree
		table 
		table_values
	    in
	    ele_comments @ elements @ (iter new_env (item.Parsetree.pstr_loc.Location.loc_end + maybe_more) q)
      in
      iter env last_pos parsetree

   (** Analysis of a parse tree structure item to obtain a new environment and a list of elements.*)
   and analyse_structure_item env current_module_name loc pos_limit comment_opt parsetree_item_desc typedtree 
	table table_values = 
      print_DEBUG "Odoc_ast:analyse_struture_item";
      match parsetree_item_desc with
	Parsetree.Pstr_eval _ ->
	  (* don't care *)
	  (0, env, [])
      | Parsetree.Pstr_value (rec_flag, pat_exp_list) ->
	  (* of rec_flag * (pattern * expression) list *)
	  (* For each value, look for the value name, then look in the
	     typedtree for the corresponding information,
	     at last analyse this information to build the value *)
	  let rec iter_pat = function
	    | Parsetree.Ppat_any -> None
	    | Parsetree.Ppat_var name -> Some name
	    | Parsetree.Ppat_tuple _ -> None (* A VOIR quand on traitera les tuples *)
	    | Parsetree.Ppat_constraint (pat, _) -> iter_pat pat.Parsetree.ppat_desc
	    | _ -> None
	  in
	  let rec iter ?(first=false) last_pos acc_env acc p_e_list =
	    match p_e_list with
	      [] ->
		(acc_env, acc)
	    | (pat, exp) :: q ->
		let value_name_opt = iter_pat pat.Parsetree.ppat_desc in
		let new_last_pos = exp.Parsetree.pexp_loc.Location.loc_end in
		match value_name_opt with
		  None ->
		    iter new_last_pos acc_env acc q
		| Some name ->
		    try
		      let pat_exp = Typedtree_search.search_value table_values name in
		      let (info_opt, ele_comments) =
			(* we already have the optional comment for the first value. *)
			if first then
			  (comment_opt, [])
			else
			  get_comments_in_module
			    last_pos 
			    pat.Parsetree.ppat_loc.Location.loc_start
		      in
		      let l_values = tt_analyse_value 
			  env
			  current_module_name
			  info_opt
			  loc
			  pat_exp
			  rec_flag
		      in
		      let new_env = List.fold_left 
			  (fun e -> fun v ->
			    Odoc_env.add_value e v.val_name
			  )
			  acc_env
			  l_values
		      in
		      let l_ele = List.map (fun v -> Element_value v) l_values in
		      iter 
			new_last_pos 
			new_env 
			(acc @ ele_comments @ l_ele)
			q
		    with
		      Not_found ->
			iter new_last_pos acc_env acc q
	  in
	  let (new_env, l_ele) = iter ~first: true loc.Location.loc_start env [] pat_exp_list in
	  (0, new_env, l_ele)

      | Parsetree.Pstr_primitive (name_pre, val_desc) ->
	  (* of string * value_description *)
	  print_DEBUG ("Parsetree.Pstr_primitive ("^name_pre^", ["^(String.concat ", " val_desc.Parsetree.pval_prim)^"]");
	  let typ = Typedtree_search.search_primitive table name_pre in
	  let name = Name.parens_if_infix name_pre in
	  let complete_name = Name.concat current_module_name name in
	  let new_value = {
	     val_name = complete_name ;
	     val_info = comment_opt ;
	     val_type = Odoc_env.subst_type env typ ;
	     val_recursive = false ;
	     val_parameters = [] ;
	     val_code = Some (get_string_of_file loc.Location.loc_start loc.Location.loc_end) ;
	     val_loc = { loc_impl = Some (!file_name, loc.Location.loc_start) ; loc_inter = None } ;
	   }	
	   in
	  let new_env = Odoc_env.add_value env new_value.val_name in
	  (0, new_env, [Element_value new_value])

      | Parsetree.Pstr_type name_typedecl_list ->
	  (* of (string * type_declaration) list *)
	  (* we start by extending the environment *)
	  let new_env =
	    List.fold_left 
	      (fun acc_env -> fun (name, _) ->
		let complete_name = Name.concat current_module_name name in
		Odoc_env.add_type acc_env complete_name
	      )
	      env
	      name_typedecl_list
	  in
	  let rec f ?(first=false) maybe_more_acc last_pos name_type_decl_list =
	    match name_type_decl_list with
	      [] -> (maybe_more_acc, [])
	    | (name, type_decl) :: q ->
		let complete_name = Name.concat current_module_name name in
		let loc_start = type_decl.Parsetree.ptype_loc.Location.loc_start in
		let loc_end =  type_decl.Parsetree.ptype_loc.Location.loc_end in
		let pos_limit2 = 
		  match q with 
		    [] -> pos_limit
		  | (_, td) :: _ -> td.Parsetree.ptype_loc.Location.loc_start
		in
		let (maybe_more, name_comment_list) = 
		    Sig.name_comment_from_type_kind
		      loc_start loc_end
		      pos_limit2
		      type_decl.Parsetree.ptype_kind
		in
		let tt_type_decl = 
		  try Typedtree_search.search_type_declaration table name 
		  with Not_found -> raise (Failure (Odoc_messages.type_not_found_in_typedtree complete_name))
		in
		let (com_opt, ele_comments) = (* the comment for the first type was already retrieved *)
		  if first then
		    (comment_opt , [])
		  else
		    get_comments_in_module last_pos loc_start
		in
		let kind = Sig.get_type_kind
		    new_env name_comment_list
		    tt_type_decl.Types.type_kind
		in
		let t =
		  {
		    ty_name = complete_name ;
		    ty_info = com_opt ;
		    ty_parameters = List.map
		      (Odoc_env.subst_type new_env) 
		      tt_type_decl.Types.type_params ;
		    ty_kind = kind ;
		    ty_manifest =
		    (match tt_type_decl.Types.type_manifest with
		      None -> None
		    | Some t -> Some (Odoc_env.subst_type new_env t));
		    ty_loc = { loc_impl = Some (!file_name, loc_start) ; loc_inter = None } ;
		  } 
		in
		let new_end = loc_end + maybe_more in
		let (maybe_more2, info_after_opt) = 
		  My_ir.just_after_special
		    !file_name
		    (get_string_of_file new_end pos_limit2)
		in
		t.ty_info <- Sig.merge_infos t.ty_info info_after_opt ;
		let (maybe_more3, eles) = f (maybe_more + maybe_more2) (new_end + maybe_more2) q in
		(maybe_more3, ele_comments @ ((Element_type t) :: eles))
	  in
	  let (maybe_more, eles) = f ~first: true 0 loc.Location.loc_start name_typedecl_list in
	  (maybe_more, new_env, eles)

      | Parsetree.Pstr_exception (name, excep_decl) ->
	  (* a new exception is defined *)
	  let complete_name = Name.concat current_module_name name in
	  (* we get the exception declaration in the typed tree *)
	  let tt_excep_decl = 
	    try Typedtree_search.search_exception table name 
	    with Not_found -> 
	      raise (Failure (Odoc_messages.exception_not_found_in_typedtree complete_name))
	  in
	  let new_env = Odoc_env.add_exception env complete_name in
	  let new_ex = 
	    {
	      ex_name = complete_name ;
	      ex_info = comment_opt ;
	      ex_args = List.map (Odoc_env.subst_type new_env) tt_excep_decl ;
	      ex_alias = None ;
	      ex_loc = { loc_impl = Some (!file_name, loc.Location.loc_start) ; loc_inter = None } ;
	    } 
	  in
	  (0, new_env, [ Element_exception new_ex ])

      | Parsetree.Pstr_exn_rebind (name, _) ->
	  (* a new exception is defined *)
	  let complete_name = Name.concat current_module_name name in
	  (* we get the exception rebind in the typed tree *)
	  let tt_path = 
	    try Typedtree_search.search_exception_rebind table name 
	    with Not_found -> 
	      raise (Failure (Odoc_messages.exception_not_found_in_typedtree complete_name))
	  in
	  let new_env = Odoc_env.add_exception env complete_name in
	  let new_ex = 
	    {
	      ex_name = complete_name ;
	      ex_info = comment_opt ;
	      ex_args = [] ;
	      ex_alias = Some { ea_name = (Odoc_env.full_exception_name env (Name.from_path tt_path)) ;
				ea_ex = None ; } ;
	      ex_loc = { loc_impl = Some (!file_name, loc.Location.loc_start) ; loc_inter = None } ;
	    } 
	  in
	  (0, new_env, [ Element_exception new_ex ])

      | Parsetree.Pstr_module (name, module_expr) ->
	  (
	   (* of string * module_expr *)
	   try
	     let tt_module_expr = Typedtree_search.search_module table name in
	     let new_module = analyse_module 
		 env
		 current_module_name
		 name
		 comment_opt
		 module_expr
		 tt_module_expr
	     in
	     let new_env = Odoc_env.add_module env new_module.m_name in
	     let new_env2 = 
	       match new_module.m_type with
                 (* A VOIR : cela peut-il �tre Tmty_ident ? dans ce cas, on aurait pas la signature *)
		 Types.Tmty_signature s -> 
		   Odoc_env.add_signature new_env new_module.m_name
		     ~rel: (Name.simple new_module.m_name) s
	       | _ -> 
		   new_env
	     in
	     (0, new_env2, [ Element_module new_module ])
	   with
	     Not_found ->
	       let complete_name = Name.concat current_module_name name in
	       raise (Failure (Odoc_messages.module_not_found_in_typedtree complete_name))
	  )

      | Parsetree.Pstr_modtype (name, modtype) ->
	  let complete_name = Name.concat current_module_name name in
	  let tt_module_type =
	    try Typedtree_search.search_module_type table name
	    with Not_found -> 
	      raise (Failure (Odoc_messages.module_type_not_found_in_typedtree complete_name))
	  in
	  let kind = Sig.analyse_module_type_kind env complete_name
	      modtype tt_module_type
	  in
	  let mt = 
	    {
	      mt_name = complete_name ;
	      mt_info = comment_opt ;
	      mt_type = Some tt_module_type ;
	      mt_is_interface = false ;
	      mt_file = !file_name ;
	      mt_kind = Some kind ; 
	      mt_loc = { loc_impl = Some (!file_name, loc.Location.loc_start) ; loc_inter = None } ;
	    } 
	  in
	  let new_env = Odoc_env.add_module_type env mt.mt_name in
	  let new_env2 =
	    match tt_module_type with 
              (* A VOIR : cela peut-il �tre Tmty_ident ? dans ce cas, on n'aurait pas la signature *)
	      Types.Tmty_signature s -> 
		Odoc_env.add_signature new_env mt.mt_name ~rel: (Name.simple mt.mt_name) s
	    | _ -> 
		new_env
	  in
	  (0, new_env2, [ Element_module_type mt ])
    
      | Parsetree.Pstr_open longident ->
	  (* A VOIR : enrichir l'environnement quand open ? *)
	  let ele_comments = match comment_opt with
	    None -> []
	  | Some i ->
	      match i.i_desc with
		None -> []
	      |	Some t -> [Element_module_comment t]
	  in
	  (0, env, ele_comments)

      | Parsetree.Pstr_class class_decl_list ->
          (* we start by extending the environment *)
	  let new_env =
	    List.fold_left 
	      (fun acc_env -> fun class_decl ->
		let complete_name = Name.concat current_module_name class_decl.Parsetree.pci_name in
		Odoc_env.add_class acc_env complete_name
	      )
	      env
	      class_decl_list
	  in
	  let rec f ?(first=false) last_pos class_decl_list =
	    match class_decl_list with
	      [] ->
		[]
	    | class_decl :: q ->
		let (tt_class_exp, tt_type_params) =
		  try Typedtree_search.search_class_exp table class_decl.Parsetree.pci_name 
		  with Not_found ->
		    let complete_name = Name.concat current_module_name class_decl.Parsetree.pci_name in
		    raise (Failure (Odoc_messages.class_not_found_in_typedtree complete_name))
		in
		let (com_opt, ele_comments) =
		  if first then
		    (comment_opt, [])
		  else
		    get_comments_in_module last_pos class_decl.Parsetree.pci_loc.Location.loc_start 
		in
		let last_pos2 = class_decl.Parsetree.pci_loc.Location.loc_end in
		let new_class = analyse_class 
		    new_env
		    current_module_name
		    com_opt
		    class_decl
		    tt_type_params
		    tt_class_exp
		in
		ele_comments @ ((Element_class new_class) :: (f last_pos2 q))
	  in
	  (0, new_env, f ~first: true loc.Location.loc_start class_decl_list)

      | Parsetree.Pstr_class_type class_type_decl_list ->
	  (* we start by extending the environment *)
	  let new_env =
	    List.fold_left 
	      (fun acc_env -> fun class_type_decl ->
		let complete_name = Name.concat current_module_name class_type_decl.Parsetree.pci_name in
		Odoc_env.add_class_type acc_env complete_name
	      )
	      env
	      class_type_decl_list
	  in
	  let rec f ?(first=false) last_pos class_type_decl_list =
	    match class_type_decl_list with
	      [] ->
		[]
	    | class_type_decl :: q ->
		let name = class_type_decl.Parsetree.pci_name in
		let complete_name = Name.concat current_module_name name in
		let virt = class_type_decl.Parsetree.pci_virt = Asttypes.Virtual in
		let tt_cltype_declaration =
		  try Typedtree_search.search_class_type_declaration table name 
		  with Not_found -> 
		    raise (Failure (Odoc_messages.class_type_not_found_in_typedtree complete_name))
		in
		let type_params = tt_cltype_declaration.Types.clty_params in
		let kind = Sig.analyse_class_type_kind
		    new_env
		    complete_name
		    class_type_decl.Parsetree.pci_loc.Location.loc_start
		    class_type_decl.Parsetree.pci_expr
		    tt_cltype_declaration.Types.clty_type
		in
		let (com_opt, ele_comments) =
		  if first then
		    (comment_opt, [])
		  else
		    get_comments_in_module last_pos class_type_decl.Parsetree.pci_loc.Location.loc_start 
		in
		let last_pos2 = class_type_decl.Parsetree.pci_loc.Location.loc_end in
		let new_ele =
		  Element_class_type
		    {
		      clt_name = complete_name ;
		      clt_info = com_opt ;
		      clt_type = Odoc_env.subst_class_type env tt_cltype_declaration.Types.clty_type ;
		      clt_type_parameters = List.map (Odoc_env.subst_type new_env) type_params ;
		      clt_virtual = virt ;
		      clt_kind = kind ;
		      clt_loc = { loc_impl = Some (!file_name, loc.Location.loc_start) ; 
				  loc_inter = None } ;
		    } 
		in
		ele_comments @ (new_ele :: (f last_pos2 q))
	  in
	  (0, new_env, f ~first: true loc.Location.loc_start class_type_decl_list)

      | Parsetree.Pstr_include module_expr ->
	  (* we add a dummy included module which will be replaced by a correct
	     one at the end of the module analysis,
	     to use the Path.t of the included modules in the typdtree. *)
	  let im = 
	    {
	      im_name = "dummy" ;
	      im_module = None ;
	    } 
	  in
	  (0, env, [ Element_included_module im ]) (* A VOIR : �tendre l'environnement ? avec quoi ? *)

     (** Analysis of a [Parsetree.module_expr] and a name to return a [t_module].*)
     and analyse_module env current_module_name module_name comment_opt p_module_expr tt_module_expr =
      let complete_name = Name.concat current_module_name module_name in
      let pos_start = p_module_expr.Parsetree.pmod_loc.Location.loc_start in
      let pos_end = p_module_expr.Parsetree.pmod_loc.Location.loc_end in
      let modtype = tt_module_expr.Typedtree.mod_type in
      let m_base =
	{
	  m_name = complete_name ;
	  m_type = tt_module_expr.Typedtree.mod_type ;
	  m_info = comment_opt ;
	  m_is_interface = false ;
	  m_file = !file_name ;
	  m_kind = Module_struct [] ;
	  m_loc = { loc_impl = Some (!file_name, pos_start) ; loc_inter = None } ;
	  m_top_deps = [] ;
      }	
      in
      match (p_module_expr.Parsetree.pmod_desc, tt_module_expr.Typedtree.mod_desc) with
	(Parsetree.Pmod_ident longident, Typedtree.Tmod_ident path) ->
	  let alias_name = Odoc_env.full_module_name env (Name.from_path path) in
	  { m_base with m_kind = Module_alias { ma_name = alias_name ; 
						ma_module = None ; } }
	    
      | (Parsetree.Pmod_structure p_structure, Typedtree.Tmod_structure tt_structure) ->
	  let elements = analyse_structure env complete_name pos_start pos_end p_structure tt_structure in
	  (* we must complete the included modules *)
	  let included_modules_from_tt = tt_get_included_module_list tt_structure in
	  let elements2 = replace_dummy_included_modules elements included_modules_from_tt in
	  { m_base with m_kind = Module_struct elements2 }

      | (Parsetree.Pmod_functor (_, _, p_module_expr2), 
	 Typedtree.Tmod_functor (ident, mtyp, tt_module_expr2)) ->
	  let param =
	    {
	      mp_name = Name.from_ident ident ;
	      mp_type = Odoc_env.subst_module_type env mtyp ;		   
	    } 
	  in
	  let dummy_complete_name = Name.concat "__" param.mp_name in
	  let new_env = Odoc_env.add_module env dummy_complete_name in
	  let m_base2 = analyse_module 
	      new_env
	      current_module_name
	      module_name
	      None
	      p_module_expr2
	      tt_module_expr2
	  in
	  let kind = 
	    match m_base2.m_kind with
	      Module_functor (params, k) -> Module_functor (param :: params, m_base2.m_kind)
	    | k -> Module_functor ([param], k)
	  in
	  { m_base with m_kind = kind }

      | (Parsetree.Pmod_apply (p_module_expr1, p_module_expr2), 
	 Typedtree.Tmod_apply (tt_module_expr1, tt_module_expr2, _)) ->
	  let m1 = analyse_module 
	      env
	      current_module_name
	      module_name
	      None
	      p_module_expr1
	      tt_module_expr1
	  in
	  let m2 = analyse_module
	      env
	      current_module_name
	      module_name
	      None
	      p_module_expr2
	      tt_module_expr2
	  in
	  { m_base with m_kind = Module_apply (m1.m_kind, m2.m_kind) }

      | (Parsetree.Pmod_constraint (p_module_expr2, p_modtype), 
	 Typedtree.Tmod_constraint (tt_module_expr2, tt_modtype, _)) ->
	  (* we create the module with p_module_expr2 and tt_module_expr2 
	     but we change its type according to the constraint. 
	     A VOIR : est-ce que c'est bien ?
	  *)
	  let m_base2 = analyse_module 
	      env
	      current_module_name
	      module_name
	      None
	      p_module_expr2
	      tt_module_expr2
	  in
	  let mtkind = Sig.analyse_module_type_kind 
	      env 
	      (Name.concat current_module_name "??")
	      p_modtype tt_modtype
	  in
	  { 
	    m_base with
	    m_type = tt_modtype ; 
	    m_kind = Module_constraint (m_base2.m_kind, 
					mtkind)

(*					Module_type_alias { mta_name = "Not analyzed" ;
							    mta_module = None })
*)
	  }
 
      |	_ ->
	  raise (Failure "analyse_module: parsetree and typedtree don't match.")

     let analyse_typed_tree source_file input_file 
	 (parsetree : Parsetree.structure) (typedtree : typedtree) = 
       let (tree_structure, _) = typedtree in
       let complete_source_file =
	 try
	   let curdir = Sys.getcwd () in
	   let (dirname, basename) = (Filename.dirname source_file, Filename.basename source_file) in
	   Sys.chdir dirname ;
	   let complete = Filename.concat (Sys.getcwd ()) basename in
	   Sys.chdir curdir ;
	   complete
	 with
	   Sys_error s ->
	     prerr_endline s ;
	     incr Odoc_global.errors ;
	     source_file
       in
       prepare_file complete_source_file input_file;
       (* We create the t_module for this file. *)
       let mod_name = String.capitalize (Filename.basename (Filename.chop_extension source_file)) in
       let (len,info_opt) = My_ir.first_special !file_name !file in
       
       (* we must complete the included modules *)
       let elements = analyse_structure Odoc_env.empty mod_name len (String.length !file) parsetree tree_structure in
       let included_modules_from_tt = tt_get_included_module_list tree_structure in
       let elements2 = replace_dummy_included_modules elements included_modules_from_tt in
       let kind = Module_struct elements2 in
       let m =
	 {
	   m_name = mod_name ;
	   m_type = Types.Tmty_signature [] ;
	   m_info = info_opt ;
	   m_is_interface = false ;
	   m_file = !file_name ;
	   m_kind = kind ;
	   m_loc = { loc_impl = Some (!file_name, 0) ; loc_inter = None } ;
	   m_top_deps = [] ;
	 } 
       in
       m
  end



