if exists('b:did_ftplugin_cpp_include') && b:did_ftplugin_cpp_include
   finish
endif

if !exists('g:cpp_include_kind_order')
   " prefer tags in the order: class, struct, enum, typedef, define, function
   let g:cpp_include_kind_order = ["c", "s", "g", "t", "d", "f"]
endif

if !exists('g:cpp_include_header_extensions')
   " only consider tags from files with one of these extensions
   let g:cpp_include_header_extensions = ["h", "", "hh", "hpp", "hxx"]
else
   let g:cpp_include_header_extensions = map(g:cpp_include_header_extensions, { i, e -> tolower(e) })
endif

if !exists('g:cpp_include_show')
   let g:cpp_include_show = 1
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
