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

#include <errno.h>
#include <string.h>
#include <mlvalues.h>
#include <memory.h>
#include <signals.h>
#include "unixsupport.h"

#ifndef EAGAIN
#define EAGAIN (-1)
#endif
#ifndef EWOULDBLOCK
#define EWOULDBLOCK (-1)
#endif

CAMLprim value unix_write_r(CAML_R, value fd, value buf, value vofs, value vlen)
{
  long ofs, len, written;
  int numbytes, ret;
  char iobuf[UNIX_BUFFER_SIZE];

  Begin_root (buf);
    ofs = Long_val(vofs);
    len = Long_val(vlen);
    written = 0;
    while (len > 0) {
      numbytes = len > UNIX_BUFFER_SIZE ? UNIX_BUFFER_SIZE : len;
      memmove (iobuf, &Byte(buf, ofs), numbytes);
      caml_enter_blocking_section_r(ctx);
      ret = write(Int_val(fd), iobuf, numbytes);
      caml_leave_blocking_section_r(ctx);
      if (ret == -1) {
        if ((errno == EAGAIN || errno == EWOULDBLOCK) && written > 0) break;
        uerror_r(ctx,"write", Nothing);
      }
      written += ret;
      ofs += ret;
      len -= ret;
    }
  End_roots();
  return Val_long(written);
}

/* When an error occurs after the first loop, unix_write reports the
   error and discards the number of already written characters.
   In this case, it would be better to discard the error and return the
   number of bytes written, since most likely, unix_write will be call again,
   and the error will be reproduced and this time will be reported.
   This problem is avoided in unix_single_write, which is faithful to the
   Unix system call. */

CAMLprim value unix_single_write_r(CAML_R, value fd, value buf, value vofs, value vlen)
{
  long ofs, len;
  int numbytes, ret;
  char iobuf[UNIX_BUFFER_SIZE];

  Begin_root (buf);
    ofs = Long_val(vofs);
    len = Long_val(vlen);
    ret = 0;
    if (len > 0) {
      numbytes = len > UNIX_BUFFER_SIZE ? UNIX_BUFFER_SIZE : len;
      memmove (iobuf, &Byte(buf, ofs), numbytes);
      caml_enter_blocking_section_r(ctx);
      ret = write(Int_val(fd), iobuf, numbytes);
      caml_leave_blocking_section_r(ctx);
      if (ret == -1) uerror_r(ctx,"single_write", Nothing);
    }
  End_roots();
  return Val_int(ret);
}
