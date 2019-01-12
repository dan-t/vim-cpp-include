
function! fn#fold(iterable, fn)
   if empty(a:iterable)
      throw "fn#fold: empty iterable given"
   endif

   let init = 0
   let val = 0
   let list = type(a:iterable) == type([]) ? a:iterable : items(a:iterable)
   for i in list
      if init
         let val = a:fn(i, val)
      else
         let val = i
         let init = 1
      endif
   endfor

   return val
endfunction

" map 'fn' over 'iterable' (list or dict)
"
" Examples:
" ---------
"   fn#map([1, 2, 3], { x -> x + 1 }) 
"   => [2, 3, 4]
"
"   fn#map({'a': 1, 'b': 2}, { k, v -> [k . k, v + v] })
"   => {'aa': 2, 'bb': 4}
function! fn#map(iterable, fn)
   if type(a:iterable) == type([])
      return s:map_list(a:iterable, a:fn)
   elseif type(a:iterable) == type({})
      return s:map_dict(a:iterable, a:fn)
   endif

   throw printf("fn#map: unexpected type of 'iterable': '%s'", type(a:iterable))
endfunction

function! fn#max(iterable, ...)
   let Fn = get(a:, 1, { x -> x })
   return fn#fold(a:iterable, { x, y -> Fn(x) > Fn(y) ? x : y })
endfunction

function! fn#min(iterable, ...)
   let Fn = get(a:, 1, { x -> x })
   return fn#fold(a:iterable, { x, y -> Fn(x) < Fn(y) ? x : y })
endfunction

function! s:map_list(list, fn)
   let new_list = []
   for i in a:list
      call add(new_list, a:fn(i))
   endfor

   return new_list
endfunction

function! s:map_dict(dict, fn)
   let new_dict = {}
   for [k, v] in items(a:dict)
      let [nk, nv] = a:fn(k, v)
      let new_dict[nk] = nv
   endfor

   return new_dict
endfunction
