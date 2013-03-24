"
" SExp new parser
"
"

call vimside#sexp#Make_Boolean(0)

function! ParseFile(filepath)
  if ! filereadable(a:filepath)
    throw "Error: ParseFile file not readable: ". a:filepath
  endif

  let lines = readfile(a:filepath)
  let in = join(lines, "\n")

  return Parse(in)
endfunction

function! Parse(in)
  let slist = s:SubParser(a:in)
" echo "Parse MID slist=". string(slist)
  return slist.value[0]
endfunction

" return
function! s:SubParser(in)
  let in = a:in
  let len = len(in)
  let pos = 0
" echo "s:SubParser TOP in=". in

  let sexps = []
  let token_start = -1

  while pos < len
    let c = in[pos]

    if c == ' ' || c == "\n" || c == "\t"
      " whitespace
      if token_start != -1
        let token = in[token_start : pos-1]
        let sexp = s:MakeSExp(token)
        call add(sexps, sexp)
        let token_start = -1
      endif

    elseif c == ';'
      " consume commnet
      let pos += 1
      while pos < len && in[pos] != '\n'
        let pos += 1
      endwhile

    elseif c == '"'
      " its a string
      let end = s:FindMatchingDoubleQuote(in, pos+1, len)
      let sexp = vimside#sexp#Make_String(in[pos+1 : end-1])
      call add(sexps, sexp)
      let pos = end + 1

    elseif c == '('
      " parse the list
      let [sexp, end] = s:ParseList(in, pos+1, len)
" echo "s:SubParser list sexp=". string(sexp)
      call add(sexps, sexp)
      let pos = end + 1

    elseif token_start == -1
      " its a token
      let token_start = pos

    endif

    let pos += 1
  endwhile

  if token_start != -1
    let token = in[token_start : pos-1]
    let sexp = s:MakeSExp(token)
    call add(sexps, sexp)
  endif

" echo "s:SubParser BOTTOM sexps=". string(sexps)
  return vimside#sexp#Make_List(sexps[0])
endfunction

" return [sexp_list, end] 
function! s:ParseList(in, pos, len)
  let in = a:in
  let pos = a:pos
  let len = a:len
" echo "s:ParseList TOP in=". in[pos :]

  let sexps = []
  let token_start = -1

  while pos < len
    let c = in[pos]

    if c == ' ' || c == "\n" || c == "\t"
      " whitespace
      if token_start != -1
        let token = in[token_start : pos-1]
        let sexp = s:MakeSExp(token)
" echo "s:Parser token sexp=". string(sexp)
        call add(sexps, sexp)
        let token_start = -1
      endif

    elseif c == ';'
      " consume commnet
      let pos += 1
      while pos < len && in[pos] != '\n'
        let pos += 1
      endwhile

    elseif c == '"'
      " its a string
      let end = s:FindMatchingDoubleQuote(in, pos+1, len)
      let sexp = vimside#sexp#Make_String(in[pos+1 : end-1])
      call add(sexps, sexp)
      let pos = end

    elseif c == '('
      " parse the list
      let [sexp, end] = s:ParseList(in, pos+1, len)
" echo "s:ParseList list sexp=". string(sexp)
      call add(sexps, sexp)
      let pos = end

    elseif c == ')'
      if token_start != -1
        let token = in[token_start : pos-1]
        let sexp = s:MakeSExp(token)
" echo "s:ParseList token sexp=". string(sexp)
        call add(sexps, sexp)
      endif
      return [vimside#sexp#Make_List(sexps), pos]

    elseif token_start == -1
      " its a token
      let token_start = pos

    endif

    let pos += 1
  endwhile

  throw "ERROR: could not find matching list ')' pos=" . pos

endfunction


" return pos
function! s:FindMatchingDoubleQuote(in, pos, len)
  let in = a:in
  let pos = a:pos
  let len = a:len

  while pos < len
    let c = in[pos]
    if c == '"'
      return pos
    elseif c == "\\"
      " skip next character
      let pos += 1
    endif

    let pos += 1
  endwhile

  throw "ERROR: could not find matching double quote pos=" . pos

endfunction

function! s:MakeSExp(s)
  let s = a:s
  if s == 'nil'
    return { 'sexp_type': g:SEXP_BOOLEAN_TYPE_VALUE, 'value': 0 }
  elseif s == 't'
    return { 'sexp_type': g:SEXP_BOOLEAN_TYPE_VALUE, 'value': 1 }

  elseif s =~ '^-\?\d\+$'
    return { 'sexp_type': g:SEXP_INT_TYPE_VALUE, 'value': 0+s }

  elseif s =~ '^:[a-zA-Z][a-zA-Z0-9-_:]*$'
    return { 'sexp_type': g:SEXP_KEYWORD_TYPE_VALUE, 'value': s }

  elseif s =~ '^[a-zA-Z][a-zA-Z0-9-:]*$'
    return { 'sexp_type': g:SEXP_SYMBOL_TYPE_VALUE, 'value': s }

  elseif s[0] == "'" 
    let sym = s[1:]
    if sym =~ '^[a-zA-Z][a-zA-Z0-9-:]*$'
      return { 'sexp_type': g:SEXP_SYMBOL_TYPE_VALUE, 'value': sym }
    endif
  endif

  throw "Error: s:MakeSExp: <" .s. ">"

endfunction

