let s:has_windows_os = has('win32') || has('win64')

function cpp_include#include(symbol)
   if !s:has_valid_settings()
      return
   endif

   let tags = s:taglist('^' . a:symbol . '$')
   call filter(tags, { i, t -> s:is_cpp_header_file(t.filename) })
   for tag in tags
      let [kind, dir] = s:file_kind_and_dir(tag.filename)
      let tag.file_kind = kind
      let tag.filename = substitute(tag.filename, dir, '', '')
   endfor

   if empty(tags)
      call cpp_include#print_error("couldn't find any tags for '%s'", a:symbol)
      return
   endif

   if g:cpp_include_log
      for tag in tags
         call s:log('found tag: %s', tag)
      endfor
   endif

   let tag = s:select_tag(tags)
   if empty(tag)
      return
   endif

   call s:log('selected tag: %s', tag)

   " save current cursor position
   let curpos = getcurpos() 

   let includes = s:find_all_includes()
   let tag_inc = s:find_tag_include(tag, includes)
   if !empty(tag_inc)
      call cpp_include#print_info("already present '%s' at line %d", tag_inc.string, tag_inc.line)
   else
      let best_inc = s:best_match(tag, includes)
      let inc_line = 0
      if !empty(best_inc)
         call s:log('add include below: %s', best_inc.string)
         let inc_line = best_inc.line
      else
         let inc_line = s:select_line()
      endif

      if inc_line != 0
         let tag_inc_str = s:format_include(tag)

         let inc_line_str = getline(inc_line)
         call s:log("inc_line: %d '%s'", inc_line, inc_line_str)

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

         call cpp_include#print_info("added '%s' at line %d", tag_inc_str, inc_line)
      endif
   endif

   " reset cursor position
   call cursor(curpos[1], curpos[2])
endfunction

function cpp_include#print_error(...)
   echohl ErrorMsg
   let msg = call('printf', a:000)
   echomsg printf('cpp-include: %s', msg)
   echohl None
endfunction

function cpp_include#print_info(...)
   let msg = call('printf', a:000)
   echo printf('cpp-include: %s', msg)
endfunction

function cpp_include#input(...)
   echohl Question
   let msg = printf('cpp-include: %s', call('printf', a:000))
   let data = input(msg)
   echohl None
   return data
endfunction

function cpp_include#wait_for_enter(...)
   echohl Question
   let msg = printf('cpp-include: %s   Press ENTER to continue ...', call('printf', a:000))
   call input(msg)
   echohl None
endfunction

function cpp_include#init_settings()
   if !exists('g:cpp_include_log')
      let g:cpp_include_log = 0
   elseif !exists('g:cpp_include_log_file')
      let g:cpp_include_log_file = 'vim_cpp_include.log'
   endif

   if exists('g:cpp_include_log_file')
      " clear log file
      call writefile([], g:cpp_include_log_file)
   endif

   if !exists('g:cpp_include_kinds_order')
      " prefer tags in the order: class, struct, enum, union, typedef, define, function prototype, function, extern/forward declarations
      let g:cpp_include_kinds_order = [["c", "s", "g", "u", "t", "d"], ["p", "f", "x"]]
   endif

   call s:log('cpp_include_kinds_order=%s', g:cpp_include_kinds_order)

   if !exists('g:cpp_include_header_extensions')
      " only consider tags from files with one of these extensions
      let g:cpp_include_header_extensions = ["h", "", "hh", "hpp", "hxx"]
   endif

   call s:log('cpp_include_header_extensions=%s', g:cpp_include_header_extensions)

   if !exists('g:cpp_include_locations')
      let g:cpp_include_locations = {}
   endif

   call s:log('cpp_include_locations=%s', g:cpp_include_locations)

   if !exists('g:cpp_include_default_surround')
      let g:cpp_include_default_surround = '"'
   endif

   call s:log('cpp_include_default_surround=%s', g:cpp_include_default_surround)
endfunction

function s:taglist(regex)
   " consider case when matching tags
   let old_tagcase = &tagcase
   set tagcase=match

   let tags = taglist(a:regex)

   " resetting tagcase
   let &tagcase = old_tagcase

   return tags
endfunction

" split tags by ctags kind"
function s:split_by_kind(tags)
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

function s:file_kind_and_dir(filename)
   let is_abs = s:is_absolute(a:filename)
   for [kind, data] in items(g:cpp_include_locations)
      if !has_key(data, 'dirs')
         continue
      endif

      for dir in data.dirs
         let dir = s:ensure_ends_with_seperator(dir)
         let has_file = is_abs ? a:filename =~# dir : filereadable(dir . a:filename)
         if has_file
            return [kind, dir]
         endif
      endfor
   endfor

   call s:log('no kind found for: %s', a:filename)
   return ['undefined', '']
endfunction

function s:is_cpp_header_file(filename)
   let fileext = tolower(fnamemodify(a:filename, ':e'))
   for ext in g:cpp_include_header_extensions
      if tolower(ext) == tolower(fileext)
         return 1
      endif
   endfor

   return 0
endfunction

function s:select_tag(tags)
   if empty(a:tags)
      return {}
   endif

   let filtered_tags = []
   if empty(g:cpp_include_kinds_order)
      let filtered_tags = tags
   else
      let tags_by_kind = s:split_by_kind(a:tags)
      for kinds in g:cpp_include_kinds_order
         let kinds = type(kinds) == type([]) ? kinds : [kinds]
         for kind in kinds
            if has_key(tags_by_kind, kind)
               let filtered_tags += tags_by_kind[kind]
            endif
         endfor

         if !empty(filtered_tags)
            break
         endif
      endfor
   endif

   let num_tags = len(filtered_tags)
   if num_tags == 0
      return {}
   endif

   if num_tags == 1
      return filtered_tags[0]
   endif

   let max_filename_len = fn#max(fn#map(filtered_tags, { tag -> len(tag.filename) }))

   " sort filtered_tags by filename
   let filtered_tags = sort(filtered_tags, { x, y -> x.filename > y.filename })

   let num_decs = len(printf('%d', len(filtered_tags)))
   let inputList = ['Select file to include:']
   let i = 1
   for tag in filtered_tags
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

   if idx < 1 || idx > num_tags
      return {}
   endif

   let tag = filtered_tags[idx - 1]
   return tag
endfunction

function s:select_line()
   let num_lines = line('$')
   if num_lines < 1
      return 0
   endif

   normal gg
   let old_number = &number
   set number
   redraw

   let line = cpp_include#input('Select line for include (1-%s): ', num_lines)
   echo "\n"

   " resetting number
   let &number = old_number

   redraw

   return line < 1 || line > num_lines ? 0 : line
endfunction

function s:format_include(tag)
   let surround = s:include_surround(a:tag.file_kind)
   if surround == '"'
      return printf('#include "%s"', a:tag.filename)
   elseif surround == '<' || surround == '>'
      return printf('#include <%s>', a:tag.filename)
   endif

   throw printf("unexpected include surround='%s'", surround)
endfunction

function s:include_surround(kind)
   let surround = g:cpp_include_default_surround
   if has_key(g:cpp_include_locations, a:kind)
      let loc = g:cpp_include_locations[a:kind]
      if has_key(loc, 'surround')
         let surround = loc.surround
      endif
   endif

   call s:log('kind=%s, surround=%s', a:kind, surround)
   return surround
endfunction

function s:parse_include(line)
   let include_str = getline(a:line)
   let matches = matchlist(include_str, '\v^#include[ \t]*([<"]*)([^>"]+)([>"]*)$')
   if empty(matches)
      return {}
   endif

   let path = matches[2]
   let inc = { 'path': path, 'kind': s:file_kind_and_dir(path)[0], 'string': include_str, 'line': a:line }

   call s:log('parsed include: %s', inc)

   return inc
endfunction

function s:find_tag_include(tag, includes)
   for inc in a:includes
      if a:tag.filename == inc.path
         return inc
      endif
   endfor

   return {}
endfunction

" returns a list of all includes
function s:find_all_includes()
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
      call cpp_include#wait_for_enter('#ifdef inbetween #include at line %d detected, switch to manual mode', ifdef_line)
      return []
   endif

   call map(lines, { idx, line -> s:parse_include(line) })
   return lines
endfunction

" return the include with the best match with 'tag', where they have the same
" kind ('user', 'sys') and most path components from the beginning are the
" same, or {} in the case of no match
function s:best_match(tag, includes)
   if empty(a:includes)
      return {}
   endif

   let kind_incs = deepcopy(a:includes)
   call filter(kind_incs, { idx, inc -> inc.kind == a:tag.file_kind })

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
         call s:log("new best match: num_matches=%d, path_comps='%s'", num_matches, path_comps)
         let best_inc = inc
         let best_num = num_matches
      endif
   endfor

   " in the case of no match return the last include
   return empty(best_inc) ? a:includes[-1] : best_inc
endfunction

function s:log(...)
   if g:cpp_include_log
      let msg = call('printf', a:000)
      let list = type(msg) == type([]) ? msg : [msg]
      call writefile(list, g:cpp_include_log_file, 'a')
   endif
endfunction

function s:has_valid_settings()
   if !exists('g:cpp_include_header_extensions') || empty(g:cpp_include_header_extensions)
      call cpp_include#print_error("missing header extensions in variable 'g:cpp_include_header_extensions'")
      return 0
   endif

   return 1
endfunction

" return the used path seperator in 'path', '/' or '\',
" if none is found return platform specific seperator
function s:seperator(path)
   if a:path =~ '/'
      return '/'
   elseif a:path =~ '\'
      return '\'
   endif

   return os_seperator()
endfunction

function s:os_seperator()
   return s:has_windows_os ? '\' : '/'
endfunction

function s:ensure_ends_with_seperator(path)
   if a:path !~ '\v[\\/]+$'
      let sep = s:seperator(a:path)
      return a:path . sep
   endif

   return a:path
endfunction

function s:is_absolute(path)
   if s:has_windows_os
      return a:path =~ '\v^[A-Za-z]:'
   endif

   return a:path =~ '^/'
endfunction

" copied from http://peterodding.com/code/vim/profile/autoload/xolox/path.vim
" split the path into its components:
"    s:split_path('/foo/bar/goo')   -> ['/', 'foo', 'bar', 'goo']
"    s:split_path('foo/bar/goo')    -> ['foo', 'bar', 'goo']
"    s:split_path('C:\foo\bar\goo') -> ['C:' 'foo', 'bar', 'goo']
function s:split_path(path)
   if type(a:path) == type('')
      if s:has_windows_os
         return split(a:path, '\v[\\/]+')
      else
         let absolute = (a:path =~ '^/')
         let segments = split(a:path, '\v/+')
         return absolute ? insert(segments, '/') : segments
      endif
   endif
   return []
endfunction
