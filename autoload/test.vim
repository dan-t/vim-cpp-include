function test#clear_errors()
   let v:errors = []
endfunction

function test#check_errors()
   if !empty(v:errors)
      let msg = ''
      echohl ErrorMsg
      for e in v:errors
         echomsg printf('%s', e)
      endfor
      echohl None
   endif
endfunction
