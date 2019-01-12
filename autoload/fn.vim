
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

" calls 'fn' on every item of 'iterable' and
" returns a new list/dict with the mapped items
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
" function for comparing two items
"
" Examples:
" ---------
"   fn#max([1, 2, 3])
"   => 3
"
"   fn#max([1, 2, 3], { x, y -> x > y })
"   => 3
"
"   fn#max({'a': 2, 'b': 1}, { x, y -> x[1] > y[1] })
"   => ['a', 2]
"
"   fn#max({'a': 2, 'b': 1}, { x, y -> x[0] > y[0] })
"   => ['b', 1]
function! fn#max(iterable, ...)
   let Fn = get(a:, 1, { x, y -> x > y })
   return fn#fold(a:iterable, { x, y -> Fn(x, y) ? x : y })
endfunction

" the minimum value of the items in 'iterable', optional
" function for mapping the item before comparision
"
" Examples:
" ---------
"   fn#min([1, 2, 3])
"   => 1
"
"   fn#min({'a': 2, 'b': 1}, { x, y -> x[1] < y[1] })
"   => ['b', 1]
"
"   fn#min({'a': 2, 'b': 1}, { x, y -> x[0] < x[0] })
"   => ['a', 2]
function! fn#min(iterable, ...)
   let Fn = get(a:, 1, { x, y -> x < y })
   return fn#fold(a:iterable, { x, y -> Fn(x, y) ? x : y })
endfunction

function! fn#test()
   let v:errors = []

   call assert_equal(6, fn#fold([1, 2, 3], { i, acc -> i + acc }))
   call assert_equal('abc', fn#fold(['a', 'b', 'c'], { i, acc -> acc . i }))

   call assert_equal([2, 3, 4], fn#map([1, 2, 3], { x -> x + 1 }))
   call assert_equal({'aa': 2, 'bb': 4}, fn#map({'a': 1, 'b': 2}, { kv -> [kv[0] . kv[0], kv[1] + kv[1]] }))

   call assert_equal([0, 0], fn#find([], { x -> x == 0 }))
   call assert_equal([1, 0], fn#find([0], { x -> x == 0 }))
   call assert_equal([1, 1], fn#find([0, 1], { x -> x == 1 }))
   call assert_equal([0, 0], fn#find({}, { kv -> kv[0] == 'a' }))
   call assert_equal([1, ['a', 1]], fn#find({'a': 1, 'b': 2}, { kv -> kv[0] == 'a' }))
   call assert_equal([1, ['b', 2]], fn#find({'a': 1, 'b': 2}, { kv -> kv[1] == 2 }))

   call assert_equal(3, fn#max([1, 2, 3]))
   call assert_equal(3, fn#max([1, 2, 3], { x, y -> x > y }))
   call assert_equal(['a', 2], fn#max({'a': 2, 'b': 1}, { x, y -> x[1] > y[1] }))
   call assert_equal(['b', 1], fn#max({'a': 2, 'b': 1}, { x, y -> x[0] > y[0] }))

   call assert_equal(1, fn#min([1, 2, 3]))
   call assert_equal(1, fn#min([1, 2, 3], { x, y -> x < y }))
   call assert_equal(['b', 1], fn#min({'a': 2, 'b': 1}, { x, y -> x[1] < y[1] }))
   call assert_equal(['a', 2], fn#min({'a': 2, 'b': 1}, { x, y -> x[0] < x[0] }))

   if !empty(v:errors)
      let msg = ''
      echohl ErrorMsg
      for e in v:errors
         echomsg printf('%s', e)
      endfor
      echohl None
   endif
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
