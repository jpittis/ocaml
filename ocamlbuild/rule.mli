(***********************************************************************)
(*                             ocamlbuild                              *)
(*                                                                     *)
(*  Nicolas Pouillard, Berke Durak, projet Gallium, INRIA Rocquencourt *)
(*                                                                     *)
(*  Copyright 2007 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the Q Public License version 1.0.               *)
(*                                                                     *)
(***********************************************************************)

(* $Id$ *)
(* Original author: Nicolas Pouillard *)
open My_std
open Resource

type env = Pathname.t -> Pathname.t
type builder = Pathname.t list list -> (Pathname.t, exn) Outcome.t list
type action = env -> builder -> Command.t

type 'a gen_rule = private
  { name  : string;
    tags  : Tags.t;
    deps  : Pathname.t list;
    prods : 'a list;
    code  : env -> builder -> Command.t }

type rule = Pathname.t gen_rule
type rule_scheme = resource_pattern gen_rule

type 'a rule_printer = (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a gen_rule -> unit

val rule : string ->
  ?tags:string list ->
  ?prods:string list ->
  ?deps:string list ->
  ?prod:string ->
  ?dep:string ->
  ?insert:[`top | `before of string | `after of string | `bottom] ->
  action -> unit

val file_rule : string ->
  ?tags:string list ->
  prod:string ->
  ?deps:string list ->
  ?dep:string ->
  ?insert:[`top | `before of string | `after of string | `bottom] ->
  cache:(env -> builder -> string) ->
  (env -> out_channel -> unit) -> unit

val custom_rule : string ->
  ?tags:string list ->
  ?prods:string list ->
  ?prod:string ->
  ?deps:string list ->
  ?dep:string ->
  ?insert:[`top | `before of string | `after of string | `bottom] ->
  cache:(env -> builder -> string) ->
  (env -> cached:bool -> unit) -> unit

(** [copy_rule name ?insert source destination] *)
val copy_rule : string ->
  ?insert:[`top | `before of string | `after of string | `bottom] ->
  string -> string -> unit

(** [dep tags deps] Will build [deps] when [tags] will be activated. *)
val dep : string list -> string list -> unit

module Common_commands : sig
  val mv : Pathname.t -> Pathname.t -> Command.t
  val cp : Pathname.t -> Pathname.t -> Command.t
  val cp_p : Pathname.t -> Pathname.t -> Command.t
  val ln_f : Pathname.t -> Pathname.t -> Command.t
  val ln_s : Pathname.t -> Pathname.t -> Command.t
  val rm_f : Pathname.t -> Command.t
  val touch : Pathname.t -> Command.t
  val chmod : Command.spec -> Pathname.t -> Command.t
  val cmp : Pathname.t -> Pathname.t -> Command.t
end

val print : Format.formatter -> rule -> unit
val pretty_print : 'a rule_printer

(** For system use only *)

val subst : Resource.env -> rule_scheme -> rule
val can_produce : Pathname.t -> rule_scheme -> rule option
(* val tags_matches : Tags.t -> t -> t option *)
val compare : 'a gen_rule -> 'a gen_rule -> int

val print_rule_name : Format.formatter -> 'a gen_rule -> unit
val print_rule_contents : 'a rule_printer

val get_rules : unit -> rule_scheme list

val call : builder -> rule -> unit

val build_deps_of_tags : builder -> Tags.t -> Pathname.t list