"
" test utilities
"
" Copy of many of the Ensime Lisp test utilities.
"


let g:vimside.test = {}

let g:vimside.test.buffer = "vimside-testing"
badd g:vimside.test.buffer

" The queue of tests yet to be run
let s:test_queue = []

" Asynchronous event handlers waiting for signals. 
let s:test_async_handler_stack = []


" Extra jars to include on testing classpath
let s:test_env_classpath = ""

" report error
" report interrupt


" Create file named file-name. Write contents to the file. 
" Return file's name
function! vimside#test#CreateFile(file_name, contents)
  let path = fnamemodify(a:file_name, ":p:h")
  call mkdir(path, 'p')
  execute "redir >> " . a:file_name
    silent echo a:contents
  execute "redir END"
endfunction

" Make a temporary file with prefix as part of name.
function! vimside#test#MakeTmpFile(prefix)
  let tmppath = tempname()
  let tmpfile = fnamemodify(tmppath, ":t")
  let tmpdir = fnamemodify(tmppath, ":p:h")
  let tf = tmpdir ."/". a:prefix . tmpfile

  execute "redir >> " . tf
    silent echo ""
  execute "redir END"

  call delete(tmppath)
  return tf
endfunction

" Make a temporary directory with prefix as part of name.
function! vimside#test#MakeTmpDir(prefix)
  let tmppath = tempname()
  let tmpfile = fnamemodify(tmppath, ":t")
  let tmpdir = fnamemodify(tmppath, ":p:h")
  let td = tmpdir ."/". a:prefix . tmpfile

  call mkdir(td, 'p')

  call delete(tmppath)
  return td
endfunction

" Create a temporary project directory. 
" Populate with config, source files.
" The src_files is a List of Dictionaries of the form:
"   { ':name': "file name", ':contents': "lines ..." }
" Return a Dictionary describing the project. 
" Note: Delete such projects with CleanupTmpProject.
function! vimside#test#CreateTmpProject(src_files, ...)
  let root_dir = vimside#test#MakeTmpDir("test_proj_")
  let config = {
            \ ':source-roots': ['src'],
            \ ':package': 'com.test',
            \ ':compile-jars': s:test_env_classpath,
            \ ':disable-index-on-startup': true,
            \ ':target': "target"
          \ }

  if a:0 == 1
    let extra_config = a:1
    if type(extra_config) != type({})
      throw "Bad extra config type: ". string(extra_config)
    endif
    for [key,value] in items(extra_config)
      let config[key] = value
    endfor
  endif

  let config_file = root_dir .'/'. ".ensime"
  call vimside#test#CreateFile(config_file, string(config))

  let src_dir = root_dir .'/'. "src"
  call mkdir(src_dir, 'p')
  let target_dir = root_dir .'/'. "target"
  call mkdir(target_dir, 'p')

  let src_file_names = []
  for src_file in a:src_files
    let name = src_file[':name']
    let filename = src_dir .'/'. name
    let contents = src_file[':contents']
    call vimside#test#CreateFile(filename, contents)
    call add(src_file_names, filename)
  endfor

  return {
        \ ':src-files': src_file_names,
        \ ':root-dir': root_dir,
        \ ':config-file': config_file,
        \ ':src-dir': src_dir,
        \ ':target': target_dir
      \ }

endfunction

"Destroy a temporary project directory, 
" removing all buffers visiting source files in the project.
function! vimside#test#CleanupTmpProject(proj, ...)
  let no_del = (a:000 == 1) ? a:1 : false
  let src_files = a:proj[":src-files"]
  let root_dir = a:proj[":root-dir"]

  for src_file in src_files
    if bufexists(src_file)
      bdelete! src_file
    endif
  endfor

  if ! no_del
    if match(root_dir, "/tmp") == 0
      let msg = system("/bin/rm -rf ". root_dir)

      if v:shell_error != 0
        throw "Compile error: ". msg
      endif
    endif
  endif
endfunction

let b:shared_test_state = {}

function! s:test_var_put(var, val)
  let current_buffer = bufname("%")
  if current_buffer == g:vimside.test.buffer
    let b:shared_test_state[a:var] = a:val
  else
    execute "buffer ". g:vimside.test.buffer
    let b:shared_test_state[a:var] = a:val
    execute "buffer ". current_buffer
  endif
endfunction

function! s:test_var_get(var)
  let current_buffer = bufname("%")
  if current_buffer == g:vimside.test.buffer
    return has_key(b:shared_test_state, a:var) 
            \ ? b:shared_test_state[a:var] : ''
  else
    execute "buffer ". g:vimside.test.buffer
    try
      return has_key(b:shared_test_state, a:var) 
                    \ ? b:shared_test_state[a:var] : ''
    finally
      execute "buffer ". current_buffer
    endtry
  endif
endfunction

let s:tmp_project_hello_worlds = {
                \ ':name': "hello_world.scala",
                \ ':contents': ['package com.helloworld\n',
                  \ 'class HelloWorld{\n',
                  \ '}\n',
                  \ 'object HelloWorld {\n',
                  \ 'def main(args: Array[String]) = {\n',
                  \ 'Console.println(\"Hello, world!\")\n',
                  \ '}\n',
                  \ 'def foo(a:Int, b:Int):Int = {\n',
                  \ 'a + b\n',
                  \ '}\n',
                  \ '}']
              \ }

" Compile java sources of given temporary test project.
function! vimside#test#CompileJavaProject(proj, arguments)
  let src_files = a:proj[':src-files']
  let target = a:proj[':target']

  let args = []
  call extend(args, a:arguments)
  call add(args, ["-d", target])
  call extend(args, src_files)

  let msg = system("javac ". join(args, ' '))

  if v:shell_error != 0
    throw "Compile error: ". msg
  endif
endfunction

" Driver for asynchonous tests. 
" This function is invoked from vimside core,
"   signaling events to events handlers installed by asynchronous tests.
function! vimside#test#Signal(event, value)
  let bnr =bufexists(g:vimside.test.buffer)
  if bnr != 0
    buffer g:vimside.test.buffer
    echo "Processing test event: ".string(event)." with value ". string(value)
    
    while ! empty(s:test_async_handler_stack)
      " want non-interactive mode
      let handler = s:test_async_handler_stack[0]
      let handler_event = handler[":event"]

      if handler_event == event &&
         \ (! has_key(handler, ":guard-func") || handler[":guard-func"](value) )
        let s:test_async_handler_stack = s:test_async_handler_stack[1:]
        let Func = handler[":func"]
        let is_last = empty(s:test_async_handler_stack)
        call s:test_output("...handling ". event)
        try
          call Func(value)
        catch /.*/
          echo "Error executing test: ". v:exception .", moving to next"
        endtry

      else
        call s:test_output("Got ". event .", expecting ".handler_event.". Ignoring event.")
      endif
    endwhile

    " pop test and run the next
    let s:test_queue = s:test_queue[2:]
    call s:run_next_test()
  endif
endfunction

" Helper for writing text to testing buffer.
function! s:test_output(text)
  buffer g:vimside.test.buffer
  G
  setline(1, a:text)
endfunction

" Helper for writing results to testing buffer.
function! s:test_output_results(results)
  if a:results == 1
    call s:test_output(".")
  else
    call s:test_output(string(results) . "\n")
  endif
endfunction


" Run a List of tests.
function! s:test_run_suite(suite)
  buffer g:vimside.test.buffer
  " clear buffer
  gg
  dG
  " copy list
  let s:test_queue = a:suite[:]
  call s:run_next_test()
endfunction

function! s:test_run(title, Func, ...)
  try
    call call(a:Func, a:000)
    call s:test_output_results(1)
  catch /^Vim:Interrupt$/
    call s:test_output_results("Assertion failed at ". a:title .": ". v:exception)
  catch /.*/
    call test_assert_failed()
  endtry
endfunction

function! s:test_make(title, Func)
  let test = { 
          \ ":title": a:title,
          \ ":async": 0,
          \ ":func": Func
        \ }
  return test
endfunction

" Define an asynchronous test. 
" Tests have the following structure:
"
"    title
"    trigger-expression
"    [handler]*
"
" Where:
"   title is a string that describes the test.
"   trigger-expression is some expression that either constitutes the entire
"      test, or (as is more common) invokes some process that will yield an
"      asynchronous event.
"   handler is of the form (head body)
"     Where:
"       head is of the form (event-type value-name guard-expression?)
"     Where:
"       event-type is a keyword that identifies the event class
"       value-name is the symbol to which to bind the event payload
"       guard-expression is an expression evaluated with value-name bound to
"       the payload.
"   body is an arbitrary expression evaluated with value-name bound to the
"      payload of the event.
"
" When the test is executed, trigger-expression is evaluated. The test then
" waits for an asynchronous test event. When an event is signalled, the next
" handler in line is considered. If the event type of the handler's head
" matches the type of the event and the guard-expression evaluates to true,
" the corresponding handler body is executed.
"
" Handlers must be executed in order, they cannot be skipped. The test will
" wait in an unfinished state until an event is signalled that matches the
" next handler in line.
function! s:test_async_make(title, Func)
endfunction
