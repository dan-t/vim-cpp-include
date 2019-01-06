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

   let tags = s:filter_map_tags(tags)

   if empty(tags)
      call cpp_include#print_error(printf("couldn't find any tags for '%s'", a:symbol))
      return
   endif

   call s:debug_print(printf('tags: %s', tags))

   let tag = s:select_tag(tags)
   if empty(tag)
      return
   endif

   call s:debug_print(printf('selected tag: %s', tag))

   " save current cursor position
   let curpos = getcurpos() 

   let tag_inc = s:find_include(tag)
   if !empty(tag_inc)
      call cpp_include#print_info(printf("already present '%s'", tag_inc))
   else
      let line_nums = s:find_all_includes()
      call s:debug_print(printf('include line nums: %s', line_nums))

      let inc_line_num = s:best_match(tag, line_nums)

      " in the case of no match use the last include
      if inc_line_num == 0 && !empty(line_nums)
         let inc_line_num = line_nums[-1]
      endif

      let inc_line_selected = 0
      if inc_line_num != 0
         call s:debug_print(printf('add include below: %s', getline(inc_line_num)))
      else
         let inc_line_num = s:select_line_num()
         let inc_line_selected = 1
      endif

      if inc_line_num != 0
         let inc_str = printf('#include "%s"', tag.filename)

         let inc_line = getline(inc_line_num)
         call s:debug_print(printf("inc_line='%s'", inc_line))

         " if the include line only contains whitespace, then change the line,
         " otherwise append the include string
         if inc_line =~ '\v^[ \n\t]*$'
            call setline(inc_line_num, inc_str)
         else
            call append(inc_line_num, inc_str)
            let inc_line_num += 1

            " consider the added include for resetting the cursor position
            if curpos[1] >= inc_line_num
               let curpos[1] += 1
            endif
         endif

         " only show the include line if the line wasn't explicitly selected by the user
         if g:cpp_include_show && !inc_line_selected
            " jump to the include line and highlight it
            call cursor(inc_line_num, 0)
            let old_cursorline = &cursorline
            if old_cursorline == 0
               set cursorline
            endif

            if !g:cpp_include_debug
               redraw!
            endif

            call input(printf("cpp-include: added '%s' at line %d, Press ENTER to continue", inc_str, inc_line_num))
            redraw!

            " reset cursorline setting
            if old_cursorline == 0
               set nocursorline
            endif
         else
            call cpp_include#print_info(printf("added '%s' at line %d", inc_str, inc_line_num))
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

function! s:strip_include_dirs(filename)
   let fname = a:filename
   for dir in g:cpp_include_dirs
      let fname = substitute(fname, dir, "", "")
   endfor
   return fname
endfunction

function! s:has_header_extension(filename)
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

function! s:select_line_num()
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

   let line_num = input(printf('Select line for include (1-%s): ', num_lines))
   echo "\n"

   if old_number == 0
      set nonumber
   endif

   redraw

   return line_num < 1 || line_num > num_lines ? 0 : line_num
endfunction

function! s:parse_include(include_str)
   let matches = matchlist(a:include_str, '\v^#include[ \t]*([<"]*)([^>"]+)([>"]*)$')
   if empty(matches)
      return {}
   endif

   let bracket = matches[1]
   let kind = "unknown"
   if bracket == '"'
      let kind = "user"
   elseif bracket == '<'
      let kind = "sys"
   endif

   let path = matches[2]
   return { 'path': path, 'kind': kind, 'string': a:include_str }
endfunction

function! s:find_include(tag)
   call cursor(1, 1)
   let include_str = printf('#include "%s"', a:tag.filename)
   if search(include_str, 'cn') != 0
      return include_str
   endif

   let include_str = printf('#include <%s>', a:tag.name)
   if search(include_str, 'cn') != 0
      return include_str
   endif

   return ''
endfunction

" returns a list of line numbers of all includes
function! s:find_all_includes()
   call cursor(1, 1)
   let line_nums = []
   while 1
      let line_num = search('^#include', empty(line_nums) ? 'cW' : 'W')
      if line_num == 0
         break
      endif

      call add(line_nums, line_num)
   endwhile
   return line_nums
endfunction

function! s:filter_map_tags(tags)
   let new_tags = []
   for tag in a:tags
      if !s:has_header_extension(tag.filename)
         continue
      endif

      " remove the include dir prefix from the filename
      let tag.filename = s:strip_include_dirs(tag.filename)

      call add(new_tags, tag)
   endfor

   return new_tags
endfunction

" return the line number of the include with the best match
" with 'tag', where the most path components from the beginning
" are the same or 0 in the case of no match
function! s:best_match(tag, include_line_nums)
   let tag_comps = s:split_path(a:tag.filename)
   let inc_comps = []
   for line_num in a:include_line_nums
      let inc_str = getline(line_num)
      let inc_path = s:parse_include(inc_str).path
      let inc_split = s:split_path(inc_path)
      call add(inc_comps, inc_split)
   endfor

   let best_inc = -1
   let best_num = 0
   for inc_idx in range(len(inc_comps))
      let icomps = inc_comps[inc_idx]
      let min_num_comps = min([len(tag_comps), len(icomps)])
      let num_matches = 0
      for i in range(min_num_comps)
         if tag_comps[i] != icomps[i]
            break
         endif

         let num_matches += 1
      endfor

      if num_matches >= best_num
         let best_inc = inc_idx
         let best_num = num_matches
      endif
   endfor

   return best_inc == -1 ? 0 : a:include_line_nums[best_inc]
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

   if !exists('g:cpp_include_dirs') || empty(g:cpp_include_dirs)
      call cpp_include#print_error("missing include directories in variable 'g:cpp_include_dirs'")
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
