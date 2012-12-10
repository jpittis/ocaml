/***********************************************************************/
/*                                                                     */
/*                                OCaml                                */
/*                                                                     */
/*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         */
/*                                                                     */
/*  Copyright 1996 Institut National de Recherche en Informatique et   */
/*  en Automatique.  All rights reserved.  This file is distributed    */
/*  under the terms of the GNU Library General Public License, with    */
/*  the special exception on linking described in file ../../LICENSE.  */
/*                                                                     */
/***********************************************************************/

/* $Id$ */

#define CAML_CONTEXT_ROOTS

#include <mlvalues.h>
#include <alloc.h>
#include <fail.h>
#include <memory.h>
#include "unixsupport.h"

#ifdef HAS_SOCKETS

#ifndef _WIN32
#include <netdb.h>
#endif

static value alloc_proto_entry_r(CAML_R, struct protoent *entry)
{
  value res;
  value name = Val_unit, aliases = Val_unit;

  Begin_roots2 (name, aliases);
  name = caml_copy_string_r(ctx, entry->p_name);
  aliases = caml_copy_string_array_r(ctx, (const char**)entry->p_aliases);
  res = caml_alloc_small_r(ctx, 3, 0);
    Field(res,0) = name;
    Field(res,1) = aliases;
    Field(res,2) = Val_int(entry->p_proto);
  End_roots();
  return res;
}

CAMLprim value unix_getprotobyname_r(CAML_R, value name)
{
  struct protoent * entry;
  entry = getprotobyname(String_val(name));
  if (entry == (struct protoent *) NULL) caml_raise_not_found_r(ctx);
  return alloc_proto_entry_r(ctx, entry);
}

CAMLprim value unix_getprotobynumber_r(CAML_R, value proto)
{
  struct protoent * entry;
  entry = getprotobynumber(Int_val(proto));
  if (entry == (struct protoent *) NULL) caml_raise_not_found_r(ctx);
  return alloc_proto_entry_r(ctx, entry);
}

#else

CAMLprim value unix_getprotobynumber_r(CAML_R, value proto)
{ caml_invalid_argument_r(ctx, "getprotobynumber not implemented"); }

CAMLprim value unix_getprotobyname_r(CAML_R, value name)
{ caml_invalid_argument_r(ctx, "getprotobyname not implemented"); }

#endif
