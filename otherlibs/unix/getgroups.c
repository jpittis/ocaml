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

#include <mlvalues.h>
#include <alloc.h>
#include <fail.h>

#ifdef HAS_GETGROUPS

#include <sys/types.h>
#ifdef HAS_UNISTD
#include <unistd.h>
#endif
#include <limits.h>
#include "unixsupport.h"

CAMLprim value unix_getgroups_r(CAML_R, value unit)
{
  gid_t gidset[NGROUPS_MAX];
  int n;
  value res;
  int i;

  n = getgroups(NGROUPS_MAX, gidset);
  if (n == -1) uerror_r(ctx,"getgroups", Nothing);
  res = caml_alloc_tuple_r(ctx,n);
  for (i = 0; i < n; i++)
    Field(res, i) = Val_int(gidset[i]);
  return res;
}

#else

CAMLprim value unix_getgroups_r(CAML_R, value unit)
{ caml_invalid_argument_r(ctx,"getgroups not implemented"); }

#endif
