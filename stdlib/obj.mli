(***********************************************************************)
(*                                                                     *)
(*                                OCaml                                *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the GNU Library General Public License, with    *)
(*  the special exception on linking described in file ../LICENSE.     *)
(*                                                                     *)
(***********************************************************************)

(* $Id$ *)

(** Operations on internal representations of values.

   Not for the casual user.
*)

type t

external repr : 'a -> t = "%identity"
external obj : t -> 'a = "%identity"
external magic : 'a -> 'b = "%identity"
external is_block : t -> bool = "caml_obj_is_block"
external is_int : t -> bool = "%obj_is_int"
external tag : t -> int = "caml_obj_tag_r" "reentrant" "noalloc"
external set_tag : t -> int -> unit = "caml_obj_set_tag"
external size : t -> int = "%obj_size"
external field : t -> int -> t = "%obj_field"
external set_field : t -> int -> t -> unit = "%obj_set_field"
val double_field : t -> int -> float  (* @since 3.11.2 *)
val set_double_field : t -> int -> float -> unit  (* @since 3.11.2 *)
external new_block : int -> int -> t = "caml_obj_block_r" "reentrant"
external dup : t -> t = "caml_obj_dup_r" "reentrant"
external truncate : t -> int -> unit = "caml_obj_truncate_r" "reentrant"
external add_offset : t -> Int32.t -> t = "caml_obj_add_offset"
         (* @since 3.12.0 *)

val lazy_tag : int
val closure_tag : int
val object_tag : int
val infix_tag : int
val forward_tag : int
val no_scan_tag : int
val abstract_tag : int
val string_tag : int
val double_tag : int
val double_array_tag : int
val custom_tag : int
val final_tag : int  (* DEPRECATED *)

val int_tag : int
val out_of_heap_tag : int
val unaligned_tag : int   (* should never happen @since 3.11.0 *)

(** The following two functions are deprecated.  Use module {!Marshal}
    instead. *)

val marshal : t -> string
val unmarshal : string -> int -> t * int

(* (\* FIXME: untyped globals. experimental --Luca Saiu REENTRANTRUNTIME *\) *)
(* type variable;; *)
(* external make_global : 'a -> variable = "caml_make_caml_global_r" "reentrant";; *)
(* external get_global : variable -> 'a = "caml_get_caml_global_r" "reentrant";; *)
(* external set_global : variable -> 'a -> unit  = "caml_set_caml_global_r" "reentrant";; *)
