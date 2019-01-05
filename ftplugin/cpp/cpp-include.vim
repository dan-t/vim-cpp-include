if exists('b:did_ftplugin_cpp_include') && b:did_ftplugin_cpp_include
   finish
endif

if !exists('g:cpp_include_dirs') || len(g:cpp_include_dirs) == 0
   call cpp_include#print_error("vim-cpp-include: Missing include directories in variable 'g:cpp_include_dirs'")
   finish
endif

if !exists('g:cpp_include_kind_order')
   " prefer tags in the order: class, struct, typedef, define, function
   let g:cpp_include_kind_order = ["c", "s", "t", "d", "f"]
endif

if !exists('g:cpp_include_debug')
   let g:cpp_include_debug = 0
endif

let b:did_ftplugin_cpp_include = 1

if exists('b:undo_ftplugin')
   let b:undo_ftplugin .= ' | '
else
   let b:undo_ftplugin = ''
endif

command! -nargs=1 -complete=tag CppInclude call cpp_include#include(<f-args>)

let b:undo_ftplugin .= join(map([
   \ 'CppInclude',
   \ ], '"delcommand " . v:val'), ' | ')

let b:undo_ftplugin .= ' | unlet b:did_ftplugin_cpp_include'
