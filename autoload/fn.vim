
" fold over 'iterable' with 'fn'
"
" Examples:
" ---------
"   fn#fold([1, 2, 3], { i, acc -> i + acc })
"   => 6
"
"   fn#fold(['a', 'b', 'c'], { i, acc -> acc . i })
"   => 'abc'
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
"   fn#map({'a': 1, 'b': 2}, { kv -> [kv[0] . kv[0], kv[1] + kv[1]] })
"   => {'aa': 2, 'bb': 4}
function! fn#map(iterable, fn)
   if type(a:iterable) == type([])
      return s:map_list(a:iterable, a:fn)
   elseif type(a:iterable) == type({})
      return s:map_dict(a:iterable, a:fn)
   endif

   throw printf("fn#map: unexpected type of 'iterable': '%s'", type(a:iterable))
endfunction

function! fn#find(iterable, fn)
   let found = [0, 0]
   let list = type(a:iterable) == type([]) ? a:iterable : items(a:iterable)
   for i in list
      if a:fn(i)
         let found = [1, i]
         break
      endif
   endfor

   return found
endfunction

" the maximum value of the items in 'iterable', optional
" function for mapping the item before comparision
"
" Examples:
" ---------
"   fn#max([1, 2, 3])
"   => 3
"
"   fn#max({'a': 2, 'b': 1}, { kv -> kv[1] })
"   => ['a', 2]
"
"   fn#max({'a': 2, 'b': 1}, { kv -> kv[0] })
"   => ['b', 1]
function! fn#max(iterable, ...)
   let Fn = get(a:, 1, { x -> x })
   return fn#fold(a:iterable, { x, y -> Fn(x) > Fn(y) ? x : y })
endfunction

" the minimum value of the items in 'iterable', optional
" function for mapping the item before comparision
"
" Examples:
" ---------
"   fn#min([1, 2, 3])
"   => 1
"
"   fn#min({'a': 2, 'b': 1}, { kv -> kv[1] })
"   => ['b', 1]
"
"   fn#min({'a': 2, 'b': 1}, { kv -> kv[0] })
"   => ['a', 2]
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
   for kv in items(a:dict)
      let [nk, nv] = a:fn(kv)
      let new_dict[nk] = nv
   endfor

   return new_dict
endfunction
