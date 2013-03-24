"
" test utilities
"
" Copy of many of the Ensime Lisp test utilities.
"

function! Create_file(file_name, contents)
  execute "redir >> " . a:file_name
    silent echo a:contents
  execute "redir END"
endfunction

" Create a temporary project directory with Ensime config file,
"   source file(s). 
" Return Dictionary containing project defines.
" This project should be deleted by calling Cleanup_tmp_project()
function! Create_tmp_project(src_files, extra_config)
  let tempfile = tempname()
  let root_dir = fnamemodify(tempfile, ":p:h")

  let config = {
        \ ":source-roots": ["src"],
        \ ":package": "com.test",
        \ ":compile-jars": [],
        \ ":disable-index-on-startup": 1,
        \ ":target": "target"
        \ }
  for k in keys(a:extra_config)
    let config[key] = a:extra_config[key]
  endfor

  let config_file = root_dir .'/.ensime'
  call Create_file(file_name, string(contents))

  let src_dir = root_dir ."/src"
  let target_dir = root_dir ."/target"

  call mkdir(src_dir)
  call mkdir(target_dir)

endfunction

