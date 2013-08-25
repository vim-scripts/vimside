

" return [0, ""] or [1, dic]
function! g:parseHighlight(hi)
  let l:parts = split(a:hi)
  if empty(l:parts)
    return [0, "Empty highlights"]
  else
    let l:dic = {}
    for l:part in l:parts
      let l:arg = split(l:part, "=")
      if len(l:arg) != 2
        return [0, "Bad highlight part: ". string(l:part)]
      endif
      let [l:key, l:value] = l:arg
      let l:dic[l:key] = l:value
    endfor

    return l:dic
  endif
endfunction

" return error string or "" and modifies dic parameter
function! g:adjustHighlightArgs(dic)
  let l:errorStr = ""
  for [l:key, l:value] in items(a:dic)
    if l:key == "term"
      let l:parts = split(l:value, ",")
      let l:errorStr .= g:checkHighlightAttrList(l:parts)

    elseif l:key == "cterm"
      let l:parts = split(l:value, ",")
      let l:errorStr .= g:checkHighlightAttrList(l:parts)

    elseif l:key == "ctermfg"
      let [l:n, l:es] = g:getHighlightCTermNumber(l:value)
      let a:dic[l:key] = l:n
      let l:errorStr .= l:es

    elseif l:key == "ctermbg"
      let [l:n, l:es] = g:getHighlightCTermNumber(l:value)
      let a:dic[l:key] = l:n
      let l:errorStr .= l:es

    elseif l:key == "gui"
      let l:parts = split(l:value, ",")
      let l:errorStr .= g:checkHighlightAttrList(l:parts)

    elseif l:key == "guifg"
      " TODO not checked yet
      
    elseif l:key == "guibg"
      " TODO not checked yet
      
    else
      echo "Not supported: ". l:key
    endif
    unlet l:value
  endfor
  return l:errorStr
endfunction

" return []
function! g:getHighlightCTermNumber(value)
  let l:errorStr = ""
  if a:value[0] == "#"
    let l:rgb = a:value[1:]
  else
    let [l:found, l:rgb] = vimside#color#util#ConvertName_2_RGB(a:value)
    if ! l:found
      let l:errorStr .= "Bad color name: '". a:value ."'"
      let l:rgb = "90ee90"
    endif
  endif
  return [ vimside#color#term#ConvertRGBTxt_2_Int(l:rgb), l:errorStr ]
endfunction

function! g:checkHighlightAttrList(parts)
  let l:errorStr = ""
  for l:part in a:parts
    if l:part != 'bold' && 
          \ l:part != 'underline' &&
          \ l:part != 'undercurl' &&
          \ l:part != 'reverse' &&
          \ l:part != 'inverse' &&
          \ l:part != 'italic' &&
          \ l:part != 'standout' &&
          \ l:part != 'NONE' 
      let l:errorStr .= "Error: unrecogninzed attr=". l:part
    endif
  return l:errorStr
endfunction



function! g:dotest()
  let hi="term=bold,underline cterm=NONE ctermfg=Red ctermbg=#334455 guifg=#001100 guibg=#330033"

  let dic = g:parseHighlight(hi)
  echo string(dic)
  echo g:adjustHighlightArgs(dic)
  echo string(dic)
endfunction
