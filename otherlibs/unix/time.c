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

#include <time.h>
#include <mlvalues.h>
#include <alloc.h>
#include "unixsupport.h"

CAMLprim value unix_time_r(CAML_R, value unit)
{
  return caml_copy_double_r(ctx,(double) time((time_t *) NULL));
}
