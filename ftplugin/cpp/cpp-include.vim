if exists('b:did_ftplugin_cpp_include') && b:did_ftplugin_cpp_include
   finish
endif

call cpp_include#init_settings()

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
