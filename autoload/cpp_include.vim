function! cpp_include#include(symbol)
   if !s:has_valid_settings()
      return
   endif

   " consider case when matching tags
   let old_tagcase = &tagcase
   set tagcase=match

   let tags = taglist('^' . a:symbol . '$')

   " resetting tagcase
   let &tagcase = old_tagcase

   let tags = filter(tags, { i, t -> s:is_cpp_header_file(t.filename) })
   for tag in tags
      let tag.file_kind = s:file_kind(tag.filename)
      let tag.filename = s:strip_include_dirs(tag.filename)
   endfor

   if empty(tags)
      call cpp_include#print_error(printf("couldn't find any tags for '%s'", a:symbol))
      return
   endif

   if g:cpp_include_debug
      call s:debug_print(printf('found %d tags:', len(tags)))
      for tag in tags
         echo printf('  %s', tag)
      endfor
   endif

   let tag = s:select_tag(tags)
   if empty(tag)
      return
   endif

   call s:debug_print(printf('selected tag: %s', tag))

   " save current cursor position
   let curpos = getcurpos() 

   let includes = s:find_all_includes()
   let tag_inc = s:find_tag_include(tag, includes)
   if !empty(tag_inc)
      call cpp_include#print_info(printf("already present '%s' at line %d", tag_inc.string, tag_inc.line))
   else
      if g:cpp_include_debug
         call s:debug_print(printf('found %d includes:', len(includes)))
         for inc in includes
            echo printf('  line=%d  %s', inc.line, inc.string)
         endfor
      endif

      let best_inc = s:best_match(tag, includes)
      let inc_line = 0
      let inc_line_selected = 0
      if !empty(best_inc)
         call s:debug_print(printf('add include below: %s', best_inc.string))
         let inc_line = best_inc.line
      else
         let inc_line = s:select_line()
         let inc_line_selected = 1
      endif

      if inc_line != 0
         let tag_inc_str = s:format_include(tag)

         let inc_line_str = getline(inc_line)
         call s:debug_print(printf("inc_line: %d '%s'", inc_line, inc_line_str))

         " if the include line only contains whitespace, then change the line,
         " otherwise append the include string
         if inc_line_str =~ '\v^[ \n\t]*$'
            call setline(inc_line, tag_inc_str)
         else
            call append(inc_line, tag_inc_str)
            let inc_line += 1

            " consider the added include for resetting the cursor position
            if curpos[1] >= inc_line
               let curpos[1] += 1
            endif
         endif

         " only show the include line if the line wasn't explicitly selected by the user
         if g:cpp_include_show && !inc_line_selected
            " jump to the include line and highlight it
            call cursor(inc_line, 0)
            let old_cursorline = &cursorline
            if old_cursorline == 0
               set cursorline
            endif

            if !g:cpp_include_debug
               redraw!
            endif

            call cpp_include#input(printf("added '%s' at line %d", tag_inc_str, inc_line), 1)
            redraw!

            " reset cursorline setting
            if old_cursorline == 0
               set nocursorline
            endif
         else
            call cpp_include#print_info(printf("added '%s' at line %d", tag_inc_str, inc_line))
         endif
      endif
   endif

   " reset cursor position
   call cursor(curpos[1], curpos[2])
endfunction

function! cpp_include#print_error(msg)
   echohl ErrorMsg
   echomsg printf('cpp-include: %s', a:msg)
   echohl None
endfunction

function! cpp_include#print_info(msg)
   echo printf('cpp-include: %s', a:msg)
endfunction

function! cpp_include#input(msg, show_press_enter)
   echohl Question
   let str = printf('cpp-include: %s', a:msg)
   call s:debug_print(printf("str='%s'", str))
   if a:show_press_enter
      let str .= ', Press ENTER to continue ...'
      call s:debug_print(printf("str='%s'", str))
   endif

   let data = input(str)
   echohl None
   return data
endfunction

function! s:split_by_kind(tags)
   let tags_by_kind = {}
   for tag in a:tags
      if has_key(tags_by_kind, tag.kind)
         call add(tags_by_kind[tag.kind], tag)
      else
         let tags_by_kind[tag.kind] = [tag]
      endif
   endfor
   return tags_by_kind
endfunction

function! s:file_kind(filename)
   for dir in g:cpp_include_user_dirs
      if a:filename =~# dir
         return 'user'
      endif
   endfor

   for dir in g:cpp_include_sys_dirs
      if a:filename =~# dir
         return 'sys'
      endif
   endfor

   return 'unknown'
endfunction

function! s:strip_include_dirs(filename)
   let fname = a:filename
   for dir in (g:cpp_include_user_dirs + g:cpp_include_sys_dirs)
      let fname = substitute(fname, dir, "", "")
   endfor
   return fname
endfunction

function! s:is_cpp_header_file(filename)
   let fileext = tolower(fnamemodify(a:filename, ':e'))
   for ext in g:cpp_include_header_extensions
      if ext == fileext
         return 1
      endif
   endfor

   return 0
endfunction

function! s:select_tag(tags)
   if empty(a:tags)
      return {}
   endif

   let tags_by_kind = s:split_by_kind(a:tags)
   let kind_tags = []
   for kind in g:cpp_include_kind_order
      if has_key(tags_by_kind, kind)
         let kind_tags = tags_by_kind[kind]
         break
      endif
   endfor

   let num_kind_tags = len(kind_tags)
   if num_kind_tags == 0
      return {}
   endif

   if num_kind_tags == 1
      return kind_tags[0]
   endif

   let max_filename_len = 0
   for tag in kind_tags
      let max_filename_len = max([max_filename_len, len(tag.filename)])
   endfor

   " sort kind_tags by filename
   let kind_tags = sort(kind_tags, { x, y -> x.filename > y.filename })

   let num_decs = len(printf('%d', len(kind_tags)))
   let inputList = ['Select file to include:']
   let i = 1
   for tag in kind_tags
      let num_spaces = max_filename_len - len(tag.filename) + 1
      let format_str = '%' . num_decs . 'd file: %s%' . num_spaces . 's, line: %s'

      " collapse multiple spaces to one and remove pattern match prefix and postfix
      let cmd = substitute(tag.cmd, '\v[ \t]+', ' ', 'g')
      let cmd = substitute(cmd, '\v/\^ *', '', 'g')
      let cmd = substitute(cmd, '\v\$/', '', 'g')

      let inputList += [printf(format_str, i, tag.filename, ' ', cmd)]
      let i += 1
   endfor

   let idx = inputlist(inputList)
   echo "\n"
   if idx == 0
      return {}
   endif

   if idx < 1 || idx > num_kind_tags
      return {}
   endif

   let tag = kind_tags[idx - 1]
   return tag
endfunction

function! s:select_line()
   let num_lines = line('$')
   if num_lines < 1
      return 0
   endif

   normal gg
   let old_number = &number
   if old_number == 0
      set number
   endif

   redraw

   let line = cpp_include#input(printf('Select line for include (1-%s): ', num_lines), 0)
   echo "\n"

   if old_number == 0
      set nonumber
   endif

   redraw

   return line < 1 || line > num_lines ? 0 : line
endfunction

function! s:format_include(tag)
   let kind = a:tag.file_kind
   if kind == 'user'
      return printf('#include "%s"', a:tag.filename)
   elseif kind == 'sys'
      return printf('#include <%s>', a:tag.filename)
   endif

   throw printf("unexpected kind='%s'", kind)
endfunction

function! s:parse_include(line)
   let include_str = getline(a:line)
   let matches = matchlist(include_str, '\v^#include[ \t]*([<"]*)([^>"]+)([>"]*)$')
   if empty(matches)
      return {}
   endif

   let bracket = matches[1]
   let kind = 'unknown'
   if bracket == '"'
      let kind = 'user'
   elseif bracket == '<'
      let kind = 'sys'
   endif

   let path = matches[2]
   let inc = { 'path': path, 'kind': kind, 'string': include_str, 'line': a:line }

   call s:debug_print(printf('parsed include: %s', inc))

   return inc
endfunction

function! s:find_tag_include(tag, includes)
   for inc in a:includes
      if a:tag.filename == inc.path
         return inc
      endif
   endfor

   return {}
endfunction

" returns a list of all includes
function! s:find_all_includes()
   call cursor(1, 1)
   let lines = []
   while 1
      let line = search('\v^[ \t]*#[ \t]*include', empty(lines) ? 'cW' : 'W')
      if line == 0
         break
      endif

      call add(lines, line)
   endwhile

   if empty(lines)
      return []
   endif

   " check if there's an #ifdef inbetween the #include
   call cursor(lines[0], 1)
   let ifdef_line = search('\v^[ \t]*#[ \t]*ifn?def', 'cW')
   if ifdef_line != 0 && ifdef_line < lines[-1]
      call cpp_include#input(printf('#ifdef inbetween #include at line %d detected, switch to manual mode', ifdef_line), 1)
      return []
   endif

   return map(lines, { idx, line -> s:parse_include(line) })
endfunction

" return the include with the best match with 'tag', where they have the same
" kind ('user', 'sys') and most path components from the beginning are the
" same, or {} in the case of no match
function! s:best_match(tag, includes)
   if empty(a:includes)
      return {}
   endif

   let kind_incs = filter(a:includes, { idx, inc -> inc.kind == a:tag.file_kind })

   " if no matching kind could be found, then
   " just use the last include
   if empty(kind_incs)
      return a:includes[-1]
   endif

   let tag_comps = s:split_path(a:tag.filename)

   let best_inc = {}
   let best_num = 0
   for inc in kind_incs
      let path_comps = s:split_path(inc.path)
      let min_num_comps = min([len(tag_comps), len(path_comps)])
      let num_matches = 0
      for i in range(min_num_comps)
         if tag_comps[i] != path_comps[i]
            break
         endif

         let num_matches += 1
      endfor

      if num_matches >= best_num
         call s:debug_print(printf("new best match: num_matches=%d, path_comps='%s'", num_matches, path_comps))
         let best_inc = inc
         let best_num = num_matches
      endif
   endfor

   " in the case of no match return the last include
   return empty(best_inc) ? a:includes[-1] : best_inc
endfunction

function! s:debug_print(msg)
   if g:cpp_include_debug
      echo printf('cpp-include: %s', a:msg)
   endif
endfunction

function! s:has_valid_settings()
   if !exists('g:cpp_include_kind_order') || empty(g:cpp_include_kind_order)
      call cpp_include#print_error("missing tag kind order in variable 'g:cpp_include_kind_order'")
      return 0
   endif

   if !exists('g:cpp_include_user_dirs') || empty(g:cpp_include_user_dirs)
      call cpp_include#print_error("missing include directories in variable 'g:cpp_include_user_dirs'")
      return 0
   endif

   if !exists('g:cpp_include_header_extensions') || empty(g:cpp_include_header_extensions)
      call cpp_include#print_error("missing header extensions in variable 'g:cpp_include_header_extensions'")
      return 0
   endif

   return 1
endfunction

" copied from http://peterodding.com/code/vim/profile/autoload/xolox/path.vim
let s:windows_compatible = has('win32') || has('win64')

" split the path into its components:
"    s:split_path('/foo/bar/goo')   -> ['/', 'foo', 'bar', 'goo']
"    s:split_path('foo/bar/goo')    -> ['foo', 'bar', 'goo']
"    s:split_path('C:\foo\bar\goo') -> ['C:' 'foo', 'bar', 'goo']
function! s:split_path(path)
   if type(a:path) == type('')
      if s:windows_compatible
         return split(a:path, '\v[\/]+')
      else
         let absolute = (a:path =~ '^/')
         let segments = split(a:path, '\v/+')
         return absolute ? insert(segments, '/') : segments
      endif
   endif
   return []
endfunction
