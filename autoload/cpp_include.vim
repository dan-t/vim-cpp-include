function! cpp_include#include(...)
   if !s:has_valid_settings()
      return
   endif

   if len(a:000) > 2
      call cpp_include#print_error("invalid arguments '%s'", a:000)
      return
   endif

   call s:save_vim_settings()
   call s:set_vim_settings()

   let symbol = len(a:000) >= 1 ? a:000[0] : ''
   let origin = len(a:000) == 2 ? a:000[1] : ''
   if symbol == ''
      let [csymbol, csymbol_with_namespace] = s:symbol_under_cursor()
      let symbol = csymbol
      if origin == ''
         let origin = s:symbol_origin(csymbol_with_namespace)
      endif
   endif

   if symbol == ''
      call cpp_include#print_error("missing symbol")
      call s:restore_vim_settings()
      return
   endif

   let symid = s:symbol_id(symbol, origin)
   if empty(symid)
      call cpp_include#print_error("couldn't find anything for '%s'", symbol)
      call s:restore_vim_settings()
      return
   endif

   let includes = s:find_all_includes()
   let symid_inc = s:find_include(symid, includes)
   if !empty(symid_inc)
      call cpp_include#print_info("already present '%s' at line %d", symid_inc.string, symid_inc.line)
   else
      let inc_pos = s:include_position(symid, includes)
      if empty(inc_pos)
         let inc_pos = s:select_line()
      endif

      if !empty(inc_pos)
         let include_str = s:format_include(symid)
         call s:log("symid='%s', include_str='%s'", symid, include_str)

         call s:add_include(inc_pos, include_str)

         " consider the added include for resetting the cursor position
         call s:update_saved_cursor_position(inc_pos)

         call cpp_include#print_info("added '%s' at line %d", include_str, inc_pos.line)
      endif
   endif

   call s:restore_vim_settings()
endfunction

function! cpp_include#sort()
   call s:save_vim_settings()
   call s:set_vim_settings()

   let includes = s:find_all_includes()
   if !empty(includes)
      let lines = fn#map(includes, { i -> i.line })
      call sort(includes, function('s:compare_include'))
      for i in range(min([len(lines), len(includes)]))
         call setline(lines[i], includes[i].string)
      endfor
   endif

   call s:restore_vim_settings()
endfunction

function! cpp_include#print_error(...)
   echohl ErrorMsg
   let msg = call('printf', a:000)
   echomsg printf('cpp-include: %s', msg)
   echohl None
endfunction

function! cpp_include#print_info(...)
   let msg = call('printf', a:000)
   echo printf('cpp-include: %s', msg)
endfunction

function! cpp_include#init_settings()
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

   if !exists('g:cpp_include_origins')
      let g:cpp_include_origins = []
   endif

   let [found_std, std] = fn#find(g:cpp_include_origins, { x -> x[0] == 'std' })
   if found_std
      let std_data = std[1]
      if has_key(std_data, 'version')
         let [found_vers, vers] = fn#find(['c++11', 'c++14', 'c++17'], { x -> x == std_data.version })
         if !found_vers
            cpp_include#print_error("unsupported value for 'version': '%s'", vers)
            let std_data.version = 'c++11'
         endif
      else
         let std_data.version = 'c++11'
      endif

      let std_data.directory = s:script_path . 'std-headers'
      let std_data.symbol_regex = '\v^std::'

      let std_tags_file = printf('%s%s.tags', s:script_path, std_data.version)
      exe printf('setlocal tags=%s,%s', &tags, std_tags_file)
      call s:log('setlocal tags=%s', &tags)
   endif

   call s:log('cpp_include_origins=%s', g:cpp_include_origins)

   let s:origin_to_data = {}
   for [origin, data] in g:cpp_include_origins
      let s:origin_to_data[origin] = data
   endfor

   call s:log('s:origin_to_data=%s', s:origin_to_data)

   if !exists('g:cpp_include_forced_headers')
      let g:cpp_include_forced_headers = {}
   endif

   let g:cpp_include_forced_headers.cout = { 'origin': 'std', 'path': 'iostream' }
   let g:cpp_include_forced_headers.cerr = { 'origin': 'std', 'path': 'iostream' }
   let g:cpp_include_forced_headers.cin = { 'origin': 'std', 'path': 'iostream' }
   let g:cpp_include_forced_headers.stringstream = { 'origin': 'std', 'path': 'sstream' }

   call s:log('cpp_include_forced_headers=%s', g:cpp_include_forced_headers)

   if !exists('g:cpp_include_default_surround')
      let g:cpp_include_default_surround = '"'
   endif

   call s:log('cpp_include_default_surround=%s', g:cpp_include_default_surround)

   if !exists('g:cpp_include_position_fallback')
      let g:cpp_include_position_fallback = []
   endif

   call s:log('cpp_include_position_fallback=%s', g:cpp_include_position_fallback)
endfunction

function! cpp_include#test()
   let v:errors = []

   call cpp_include#init_settings()
   call s:save_settings()

   for has_win_os in [0, 1]
      let s:has_windows_os = has_win_os
      call s:test_split_path()
      call s:test_is_absolute()
      call s:test_ensure_ends_with_seperator()
      call s:test_file_origin_and_dir()
   endfor

   call s:restore_settings()

   if !empty(v:errors)
      let msg = ''
      echohl ErrorMsg
      for e in v:errors
         echomsg printf('%s', e)
      endfor
      echohl None
   endif
endfunction

function! s:symbol_under_cursor()
   set iskeyword=@,48-57,_,192-255
   let symbol = expand('<cword>')

   set iskeyword=@,48-57,_,192-255,:
   let symbol_with_namespace = expand('<cword>')

   let sym = [symbol, symbol_with_namespace]
   call s:log("symbol_under_cursor='%s'", sym)
   return sym
endfunction

function! s:input(...)
   echohl Question
   let msg = printf('cpp-include: %s', call('printf', a:000))
   let data = input(msg)
   echohl None
   return data
endfunction

function! s:wait_for_enter(...)
   echohl Question
   let msg = printf('cpp-include: %s   Press ENTER to continue ...', call('printf', a:000))
   call input(msg)
   echohl None
endfunction

function! s:save_vim_settings()
   let s:saved_vim_settings.curpos = getcurpos()
   let s:saved_vim_settings.ignorecase = &ignorecase
   let s:saved_vim_settings.tagcase = &tagcase
   let s:saved_vim_settings.iskeyword = &iskeyword
endfunction

function! s:set_vim_settings()
   set noignorecase
   set tagcase=match
endfunction

function! s:restore_vim_settings()
   for s in keys(s:saved_vim_settings)
      if s == 'curpos'
         let curpos = s:saved_vim_settings[s]
         call cursor(curpos[1], curpos[2])
      else
         exe printf("let &%s = s:saved_vim_settings['%s']", s, s)
      endif
   endfor

   let s:saved_vim_settings = {}
endfunction

function! s:save_settings()
   let s:saved_settings = {}
   for s in s:settings
      exe printf("let s:saved_settings['%s'] = %s", s, s)
   endfor
endfunction

function! s:restore_settings()
   for s in s:settings
      exe printf("let %s = s:saved_settings['%s']", s, s)
   endfor
   let s:saved_settings = {}
endfunction

function! s:symbol_id(symbol, origin)
   " check if there's a forced origin for 'symbol'
   if has_key(g:cpp_include_forced_headers, a:symbol)
      let symid = g:cpp_include_forced_headers[a:symbol]
      call s:log("found forced origin for symbol='%s': %s", a:symbol, symid)
      let symid['symbol'] = a:symbol
      return symid
   endif

   " find a matching tag for 'symbol'
   let tags = taglist('^' . a:symbol . '$')

   " only consider tags from header files
   call filter(tags, { i, t -> s:is_cpp_header_file(t.filename) })

   " find the origin of the tag and strip in the include
   " directory from its path
   for tag in tags
      let [origin, dir] = s:file_origin_and_dir(tag.filename)
      call s:log("tag.filename='%s', origin='%s', dir='%s'", tag.filename, origin, dir)
      let tag.file_origin = origin
      let tag.filename = substitute(tag.filename, dir, '', '')
   endfor

   " ony consider tags with a matching origin
   if !empty(a:origin)
      call filter(tags, { i, t -> t.file_origin == a:origin })
   endif

   if empty(tags)
      call cpp_include#print_error("couldn't find any tags for '%s'", a:symbol)
      return {}
   endif

   if g:cpp_include_log
      for tag in tags
         call s:log('found tag: %s', tag)
      endfor
   endif

   let tag = s:select_tag(tags)
   if empty(tag)
      return {}
   endif

   call s:log('selected tag: %s', tag)

   let symid = { 'symbol': a:symbol, 'origin': tag.file_origin, 'path': tag.filename }
   call s:log("symid='%s'", symid)
   return symid
endfunction

function! s:symbol_origin(symbol)
   if a:symbol == ''
      return ''
   endif

   for [origin, data] in g:cpp_include_origins
      if has_key(data, 'symbol_regex')
         let regex = data.symbol_regex
         if a:symbol =~ regex
            call s:log("symbol_origin('%s') = '%s'", a:symbol, origin)
            return origin
         endif
      endif
   endfor

   call s:log("no origin found for symbol='%s'", a:symbol)
   return ''
endfunction

" split tags by ctags kind"
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

function! s:file_origin_and_dir(path)
   let is_abs = s:is_absolute(a:path)
   let cur_file_dir = s:ensure_ends_with_seperator(expand('%:p:h'))
   for [origin, data] in g:cpp_include_origins
      if has_key(data, 'directory')
         let dir = s:ensure_ends_with_seperator(data.directory)
         let has_file = 0
         if is_abs
            let has_file = a:path =~ dir
         elseif filereadable(dir . a:path)
            let has_file = 1
         elseif cur_file_dir =~ dir
            let has_file = filereadable(cur_file_dir . a:path)
         endif

         if has_file
            return [origin, dir]
         endif
      elseif has_key(data, 'path_regex')
         if a:path =~ data.path_regex
            return [origin, '']
         endif
      endif
   endfor

   call s:log('no origin found for: %s', a:path)
   return ['', '']
endfunction

function! s:test_file_origin_and_dir()
endfunction

function! s:sort_order(origin)
   if has_key(s:origin_to_data, a:origin)
      let loc = s:origin_to_data[a:origin]
      if has_key(loc, 'sort_order')
         return loc['sort_order']
      endif
   endif

   return s:max_sort_order() + 1
endfunction

function! s:max_sort_order()
   let sort_order = 0
   for [origin, data] in g:cpp_include_origins
      if has_key(data, 'sort_order')
         let sort_order = max([sort_order, data['sort_order']])
      endif
   endfor

   return sort_order
endfunction

function! s:is_cpp_header_file(path)
   let fileext = tolower(fnamemodify(a:path, ':e'))
   for ext in g:cpp_include_header_extensions
      if tolower(ext) == tolower(fileext)
         return 1
      endif
   endfor

   return 0
endfunction

function! s:select_tag(tags)
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
   call sort(filtered_tags, { x, y -> fn#compare(x.filename, y.filename) })

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

function! s:select_line()
   let num_lines = line('$')
   if num_lines < 1
      return 0
   endif

   normal! gg
   let old_number = &number
   set number
   redraw

   let line = s:input('Select line for include (1-%s): ', num_lines)
   echo "\n"

   " resetting number
   let &number = old_number

   redraw

   if line < 1 || line > num_lines
      return {}
   endif

   let line_str = getline(line)
   let pos = 'below'

   " if the include line only contains whitespace, then change the line
   if line_str =~ '\v^[ \n\t]*$'
      let pos = 'at'
   " if the first line is a non include line, then insert the line above
   elseif line == 1 && line_str !~ s:include_regex
      let pos = 'above'
   endif

   return { 'line': line, 'pos': pos }
endfunction

function! s:are_sorted(includes)
   if empty(a:includes)
      return 0
   endif

   let num_incs = len(a:includes)
   if num_incs == 1
      return 1
   endif

   for i in range(num_incs - 1)
      if s:compare_include(a:includes[i], a:includes[i + 1]) >= 0
         return 0
      endif
   endfor

   return 1
endfunction

function! s:format_include(symbol_id)
   let surround = s:include_surround(a:symbol_id.origin)
   if surround == '"'
      return printf('#include "%s"', a:symbol_id.path)
   elseif surround == '<' || surround == '>'
      return printf('#include <%s>', a:symbol_id.path)
   elseif surround == ''
      return printf('#include %s', a:symbol_id.path)
   endif

   throw printf("unexpected include surround='%s'", surround)
endfunction

function! s:include_surround(origin)
   let surround = g:cpp_include_default_surround
   if has_key(s:origin_to_data, a:origin)
      let loc = s:origin_to_data[a:origin]
      if has_key(loc, 'surround')
         let surround = loc.surround
      endif
   endif

   call s:log('origin=%s, surround=%s', a:origin, surround)
   return surround
endfunction

function! s:update_saved_cursor_position(include_pos)
   if a:include_pos.pos != 'at'
      let curline = s:saved_vim_settings.curpos[1]
      if curline > a:include_pos.line
         let curline += 1
      elseif curline == a:include_pos.line && a:include_pos.pos == 'above'
         let curline += 1
      endif

      let s:saved_vim_settings.curpos[1] = curline
   endif
endfunction

function! s:add_include(include_pos, include_str)
   if a:include_pos.pos == 'at'
      call setline(a:include_pos.line, a:include_str)
   else
      if a:include_pos.pos == 'above'
         if a:include_pos.line == 1
            let cur_line_str = getline(a:include_pos.line)
            call setline(a:include_pos.line, [a:include_str, cur_line_str])
         else
            call append(a:include_pos.line - 1, a:include_str)
         endif
      elseif a:include_pos.pos == 'below'
         call append(a:include_pos.line, a:include_str)
      else
         throw printf("unexpected include pos='%s'", a:include_pos.pos)
      endif
   endif
endfunction

function! s:parse_include(line, line_str)
   let matches = matchlist(a:line_str, s:include_path_regex)
   if empty(matches)
      call s:log("parse_include: no match for line_str='%s'", a:line_str)
      return {}
   endif

   let path = matches[2]
   let inc = { 'path': path, 'origin': s:file_origin_and_dir(path)[0], 'string': a:line_str, 'line': a:line }

   call s:log('parsed include: %s', inc)

   return inc
endfunction

" compare function compatible with vim's interal 'sort' function
function! s:compare_include(include1, include2)
   return s:compare_origin_and_path(a:include1.origin, a:include1.path, a:include2.origin, a:include2.path)
endfunction

function! s:compare_origin_and_path(origin1, path1, origin2, path2)
   let cmp = fn#compare(s:sort_order(a:origin1), s:sort_order(a:origin2))
   if cmp != 0
      return cmp
   endif

   return fn#compare(a:path1, a:path2)
endfunction

function! s:find_include(symbol_id, includes)
   call s:log("find_include: symbol_id='%s'", a:symbol_id)
   for inc in a:includes
      call s:log("find_include: inc='%s'", inc)
      if a:symbol_id.path == inc.path
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
      let line = search(s:include_regex, empty(lines) ? 'cW' : 'W')
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
      call s:wait_for_enter('#ifdef inbetween #include at line %d detected, switch to manual mode', ifdef_line)
      return []
   endif

   call map(lines, { idx, line -> s:parse_include(line, getline(line)) })
   return lines
endfunction

function! s:include_position(symbol_id, includes)
   if empty(a:includes)
      return s:include_position_fallback([])
   endif

   if s:are_sorted(a:includes)
      call s:log('includes are sorted')
      for inc in a:includes
         if s:compare_origin_and_path(a:symbol_id.origin, a:symbol_id.path, inc.origin, inc.path) == -1
            return { 'line': inc.line, 'pos': 'above' }
         endif
      endfor

      return { 'line': a:includes[-1].line, 'pos': 'below' }
   endif

   " the includes aren't sorted, find the best matching
   " one by comparing the compoments of the path and the
   " take the include with the most matching ones

   let origin_incs = deepcopy(a:includes)
   call filter(origin_incs, { idx, inc -> inc.origin == a:symbol_id.origin })

   let tag_comps = s:split_path(a:symbol_id.path)

   let best_inc = {}
   let best_num = 0
   for inc in origin_incs
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

   if empty(best_inc)
      return s:include_position_fallback(a:includes)
   endif

   return { 'line': best_inc.line, 'pos': 'below' }
endfunction

function! s:include_position_fallback(includes)
   " if there's no matching position fallback,
   " then just use the last include
   if !empty(a:includes)
      return { 'line': a:includes[-1].line, 'pos': 'below' }
   endif

   for fallback in g:cpp_include_position_fallback
      call s:log("trying fallback='%s'", fallback)
      if has_key(fallback, 'line_regex') && has_key(fallback, 'pos')
         " reset cursor for 'search' call
         call cursor(1, 1)
         let line_regex = fallback['line_regex']
         if type(line_regex) == type('')
            let line = search(line_regex, 'c')
            if line == 0
               continue
            endif

            call s:log("using fallback='%s'", fallback)
            return { 'line': line, 'pos': fallback['pos'] }
         elseif type(line_regex) == type([])
            let line = 0
            for regex in line_regex
               let line = search(regex, 'c')
               if line == 0
                  break
               endif
            endfor

            if line == 0
               continue
            endif

            call s:log("using fallback='%s'", fallback)
            return { 'line': line, 'pos': fallback['pos'] }
         else
            throw printf("unexpected line_regex of include position fallback='%s'", line_regex)
         endif
      elseif has_key(fallback, 'line') && has_key(fallback, 'pos')
         return fallback
      else
         throw printf("unexpected include position fallback='%s'", fallback)
      endif
   endfor

   call s:log('no fallback found')
   return {}
endfunction

function! s:log(...)
   if g:cpp_include_log
      let msg = call('printf', a:000)
      let list = type(msg) == type([]) ? msg : [msg]
      call writefile(list, g:cpp_include_log_file, 'a')
   endif
endfunction

function! s:has_valid_settings()
   if !exists('g:cpp_include_header_extensions') || empty(g:cpp_include_header_extensions)
      call cpp_include#print_error("missing header extensions in variable 'g:cpp_include_header_extensions'")
      return 0
   endif

   return 1
endfunction

" return the used path seperator in 'path', '/' or '\',
" if none is found return platform specific seperator
function! s:seperator(path)
   if a:path =~ '/'
      return '/'
   elseif a:path =~ '\'
      return '\'
   endif

   return s:os_seperator()
endfunction

function! s:os_seperator()
   return s:has_windows_os ? '\' : '/'
endfunction

function! s:ensure_ends_with_seperator(path)
   if a:path !~ '\v[\\/]+$'
      let sep = s:seperator(a:path)
      return a:path . sep
   endif

   return a:path
endfunction

function! s:test_ensure_ends_with_seperator()
   if s:has_windows_os
      call assert_equal('foo/', s:ensure_ends_with_seperator('foo/'))
      call assert_equal('foo\', s:ensure_ends_with_seperator('foo'))
      call assert_equal('bar/foo/', s:ensure_ends_with_seperator('bar/foo'))
      call assert_equal('bar\foo\', s:ensure_ends_with_seperator('bar\foo'))
      call assert_equal('C:\bar\foo\', s:ensure_ends_with_seperator('C:\bar\foo'))
      call assert_equal('C:\bar\foo\', s:ensure_ends_with_seperator('C:\bar\foo\'))
   else
      call assert_equal('foo/', s:ensure_ends_with_seperator('foo/'))
      call assert_equal('foo/', s:ensure_ends_with_seperator('foo'))
      call assert_equal('bar/foo/', s:ensure_ends_with_seperator('bar/foo'))
      call assert_equal('/bar/foo/', s:ensure_ends_with_seperator('/bar/foo'))
      call assert_equal('/bar/foo/', s:ensure_ends_with_seperator('/bar/foo/'))
   endif
endfunction

function! s:is_absolute(path)
   if s:has_windows_os
      return a:path =~ '\v^[A-Za-z]:'
   endif

   return a:path =~ '^/'
endfunction

function! s:test_is_absolute()
   if s:has_windows_os
      call assert_equal(0, s:is_absolute('foo/bar'))
      call assert_equal(0, s:is_absolute('foo'))
      call assert_equal(1, s:is_absolute('C:/foo'))
      call assert_equal(1, s:is_absolute('C:\foo'))
      call assert_equal(1, s:is_absolute('C:'))
   else
      call assert_equal(0, s:is_absolute('foo/bar'))
      call assert_equal(0, s:is_absolute('foo'))
      call assert_equal(1, s:is_absolute('/foo'))
      call assert_equal(1, s:is_absolute('/'))
   endif
endfunction

" copied from http://peterodding.com/code/vim/profile/autoload/xolox/path.vim
" split the path into its components:
"    s:split_path('/foo/bar/goo')   -> ['/', 'foo', 'bar', 'goo']
"    s:split_path('foo/bar/goo')    -> ['foo', 'bar', 'goo']
"    s:split_path('C:\foo\bar\goo') -> ['C:' 'foo', 'bar', 'goo']
function! s:split_path(path)
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

function! s:test_split_path()
   if s:has_windows_os
      call assert_equal(['foo', 'bar', 'goo'], s:split_path('foo\bar\goo'))
      call assert_equal(['foo'], s:split_path('foo'))
      call assert_equal(['C:', 'foo', 'bar', 'goo'], s:split_path('C:\foo\bar\goo'))
      call assert_equal(['C:', 'foo', 'bar', 'goo'], s:split_path('C:/foo/bar/goo'))
      call assert_equal(['C:', 'foo'], s:split_path('C:\foo'))
      call assert_equal(['C:', 'foo'], s:split_path('C:\foo\'))
      call assert_equal(['C:', 'foo'], s:split_path('C:\\foo\\'))
      call assert_equal(['C:'], s:split_path('C:\'))
      call assert_equal(['C:'], s:split_path('C:'))
   else
      call assert_equal(['foo', 'bar', 'goo'], s:split_path('foo/bar/goo'))
      call assert_equal(['foo'], s:split_path('foo'))
      call assert_equal(['/', 'foo', 'bar', 'goo'], s:split_path('/foo/bar/goo'))
      call assert_equal(['/', 'foo'], s:split_path('/foo'))
      call assert_equal(['/', 'foo'], s:split_path('/foo/'))
      call assert_equal(['/', 'foo'], s:split_path('//foo//'))
      call assert_equal(['/'], s:split_path('/'))
      call assert_equal(['/'], s:split_path('//'))
   endif
endfunction

let s:has_windows_os = has('win32') || has('win64')

let s:settings = [
   \ 'g:cpp_include_log',
   \ 'g:cpp_include_log_file',
   \ 'g:cpp_include_kinds_order',
   \ 'g:cpp_include_header_extensions',
   \ 'g:cpp_include_origins',
   \ 'g:cpp_include_default_surround',
   \ 's:origin_to_data' ]

let s:saved_vim_settings = {}

let s:include_regex = '\v^[ \t]*#[ \t]*include'
let s:include_path_regex = s:include_regex . '[ \t]*([<"]*)([^>"]+)([>"]*)'
let s:script_path = s:ensure_ends_with_seperator(expand('<sfile>:p:h'))
