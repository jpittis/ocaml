(* # generated by ./configure --prefix /home/luca/usr-patched-ocaml/ --with-debug-runtime *)
let prefix = "/home/luca/usr-patched-ocaml/";;
let bindir = prefix^"/bin";;
let libdir = prefix^"/lib/ocaml";;
let stublibdir = libdir^"/stublibs";;
let mandir = prefix^"/man";;
let manext = "1";;
let ranlib = "ranlib";;
let ranlibcmd = "ranlib";;
let arcmd = "ar";;
let sharpbangscripts = true;;
let bng_arch = "ppc";;
let bng_asm_level = "1";;
let pthread_link = "-cclib -lpthread";;
let x11_includes = "not found";;
let x11_link = "not found";;
let tk_defs = "";;
let tk_link = "";;
let libbfd_link = "";;
let bytecc = "gcc";;
let bytecccompopts = "-fno-defer-pop -Wall -D_FILE_OFFSET_BITS=64 -D_REENTRANT";;
let bytecclinkopts = " -Wl,-E";;
let bytecclibs = " -lm  -ldl -lcurses -lpthread";;
let byteccrpath = "-Wl,-rpath,";;
let exe = "";;
let supports_shared_libraries = true;;
let sharedcccompopts = "-fPIC";;
let mksharedlibrpath = "-Wl,-rpath,";;
let natdynlinkopts = "-Wl,-E";;
(* SYSLIB=-l"^1^" *)
let syslib x = "-l"^x;;

(* ## *)
(* MKLIB=ar rc "^1^" "^2^"; ranlib "^1^" *)
let mklib out files opts = Printf.sprintf "ar rc %s %s %s; ranlib %s" out opts files out;;
let arch = "power";;
let model = "ppc";;
let system = "elf";;
let nativecc = "gcc";;
let nativecccompopts = "-Wall -D_FILE_OFFSET_BITS=64 -D_REENTRANT";;
let nativeccprofopts = "-Wall -D_FILE_OFFSET_BITS=64 -D_REENTRANT";;
let nativecclinkopts = "";;
let nativeccrpath = "-Wl,-rpath,";;
let nativecclibs = " -lm  -ldl -lpthread";;
let asm = "as -u -m ppc";;
let aspp = "gcc -c";;
let asppprofflags = "-DPROFILING";;
let profiling = "noprof";;
let dynlinkopts = " -ldl";;
let otherlibraries = "unix str num dynlink bigarray systhreads threads";;
let debugger = "ocamldebugger";;
let cc_profile = "-pg";;
let systhread_support = true;;
let partialld = "ld -r";;
let packld = partialld^" "^nativecclinkopts^" -o\ ";;
let dllcccompopts = "";;

let o = "o";;
let a = "a";;
let so = "so";;
let ext_obj = ".o";;
let ext_asm = ".s";;
let ext_lib = ".a";;
let ext_dll = ".so";;
let extralibs = "";;
let ccomptype = "cc";;
let toolchain = "cc";;
let natdynlink = true;;
let cmxs = "cmxs";;
let mkexe = bytecc;;
let mkexedebugflag = "-g";;
let mkdll = "gcc -shared";;
let mkmaindll = "gcc -shared";;
let runtimed = "runtimed";;
let camlp4 = "camlp4";;
let asm_cfi_supported = true;;
let multicontext_supported = false;;
let multicontext_enabled = false;;
