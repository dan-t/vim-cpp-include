function test#start()
   let v:errors = []
endfunction

function test#finish()
   if !empty(v:errors)
      let msg = ''
      echohl ErrorMsg
      for e in v:errors
         echomsg printf('%s', e)
      endfor
      echohl None
   endif
endfunction
