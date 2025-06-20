if exists("g:loaded_vimux") || &cp
  finish
endif
let g:loaded_vimux = 1

command -nargs=* VimuxRunCommand :call VimuxRunCommand(<args>)
command VimuxRunLastCommand :call VimuxRunLastCommand()
command VimuxCloseRunner :call VimuxCloseRunner()
command VimuxZoomRunner :call VimuxZoomRunner()
command VimuxInspectRunner :call VimuxInspectRunner()
command VimuxScrollUpInspect :call VimuxScrollUpInspect()
command VimuxScrollDownInspect :call VimuxScrollDownInspect()
command VimuxInterruptRunner :call VimuxInterruptRunner()
command -nargs=? VimuxPromptCommand :call VimuxPromptCommand(<args>)
command VimuxClearRunnerHistory :call VimuxClearRunnerHistory()
command VimuxTogglePane :call VimuxTogglePane()

function! VimuxRunCommandInDir(command, useFile)
    let l:file = ""
    if a:useFile ==# 1
        let l:file = shellescape(expand('%:t'), 1)
    endif
    call VimuxRunCommand("(cd ".shellescape(expand('%:p:h'), 1)." && ".a:command." ".l:file.")")
endfunction

function! VimuxRunLastCommand()
  if exists("g:VimuxRunnerIndex")
    call VimuxRunCommand(g:VimuxLastCommand)
  else
    echo "No last vimux command."
  endif
endfunction

function! VimuxRunCommand(command, ...)
  if !exists("g:VimuxRunnerIndex") || _VimuxHasRunner(g:VimuxRunnerIndex) == 0
    call VimuxOpenRunner()
  endif

  let l:autoreturn = 1
  if exists("a:1")
    let l:autoreturn = a:1
  endif

  let resetSequence = _VimuxOption("g:VimuxResetSequence", "q C-u C-k")
  let g:VimuxLastCommand = a:command

  call VimuxSendKeys(resetSequence)
  call VimuxSendText(a:command)

  if l:autoreturn == 1
    call VimuxSendKeys("Enter")
  endif
endfunction

function! VimuxSendText(text)
  call VimuxSendKeys('"'.escape(a:text, '\"$`').'"')
endfunction

function! VimuxSendKeys(keys)
  if exists("g:VimuxRunnerIndex")
    let l:target = g:VimuxRunnerIndex
    if exists("g:VimuxTargetSession")
      let l:target = g:VimuxTargetSession.".".g:VimuxRunnerIndex
    endif
    let l:command = "send-keys -t ".l:target." ".a:keys
    call _VimuxTmux(l:command)
  else
    echo "No vimux runner pane/window. Create one with VimuxOpenRunner"
  endif
endfunction

function! VimuxOpenRunner()
  let nearestIndex = _VimuxNearestIndex()

  if _VimuxOption("g:VimuxUseNearest", 1) == 1 && nearestIndex != -1
    let g:VimuxRunnerIndex = nearestIndex
  else
    if _VimuxRunnerType() == "pane"
      let height = _VimuxOption("g:VimuxHeight", 20)
      let orientation = _VimuxOption("g:VimuxOrientation", "v")
      call _VimuxTmux("split-window -p ".height." -".orientation)
    elseif _VimuxRunnerType() == "window"
      call _VimuxTmux("new-window")
    endif

    let g:VimuxRunnerIndex = _VimuxTmuxIndex()
    call _VimuxTmux("last-"._VimuxRunnerType())
  endif
endfunction

function! VimuxCloseRunner()
  if exists("g:VimuxRunnerIndex")
    call _VimuxTmux("kill-"._VimuxRunnerType()." -t ".g:VimuxRunnerIndex)
    unlet g:VimuxRunnerIndex
  endif
endfunction

function! VimuxTogglePane()
  if exists("g:VimuxRunnerIndex")
    if _VimuxRunnerType() == "window"
        call _VimuxTmux("join-pane -d -s ".g:VimuxRunnerIndex." -p "._VimuxOption("g:VimuxHeight", 20))
        let g:VimuxRunnerType = "pane"
    elseif _VimuxRunnerType() == "pane"
		let g:VimuxRunnerIndex=substitute(_VimuxTmux("break-pane -d -t ".g:VimuxRunnerIndex." -P -F '#{window_index}'"), "\n", "", "")
        let g:VimuxRunnerType = "window"
    endif
  endif
endfunction

function! VimuxZoomRunner()
  if exists("g:VimuxRunnerIndex")
    if _VimuxRunnerType() == "pane"
      call _VimuxTmux("resize-pane -Z -t ".g:VimuxRunnerIndex)
    elseif _VimuxRunnerType() == "window"
      call _VimuxTmux("select-window -t ".g:VimuxRunnerIndex)
    endif
  endif
endfunction

function! VimuxInspectRunner()
  call _VimuxTmux("select-"._VimuxRunnerType()." -t ".g:VimuxRunnerIndex)
  call _VimuxTmux("copy-mode")
endfunction

function! VimuxSetTargetRunnerIndex(target)
  let g:VimuxRunnerIndex = a:target
endfunction

function! VimuxSetTargetSession(target)
  let l:changed = !exists("g:VimuxTargetSession") || g:VimuxTargetSession != a:target
  let g:VimuxTargetSession = a:target
  if l:changed
    let g:VimuxRunnerIndex = -1
  endif
endfunction

function! VimuxCopyModeRunner()
  call _VimuxTmux("copy-mode -t ".g:VimuxRunnerIndex)
endfunction

function! VimuxSendCopyModeKeys(keys)
  call _VimuxTmux("copy-mode -t ".g:VimuxRunnerIndex)
  call VimuxSendKeys(a:keys)
endfunction

function! VimuxSendCopyModeText(text)
  call _VimuxTmux("copy-mode -t ".g:VimuxRunnerIndex)
  call VimuxSendText(a:text)
endfunction

function! VimuxScrollUpInspect()
  call VimuxSendCopyModeKeys("C-u")
endfunction

function! VimuxScrollDownInspect()
  call VimuxSendCopyModeKeys("C-d")
endfunction

function! VimuxScrollTopInspect()
  call VimuxSendCopyModeText("gg")
endfunction

function! VimuxScrollBottomInspect()
  call VimuxSendCopyModeText("G")
endfunction

function! VimuxInterruptRunner()
  call VimuxSendKeys("^c")
endfunction

function! VimuxClearRunnerHistory()
  if exists("g:VimuxRunnerIndex")
    call _VimuxTmux("clear-history -t ".g:VimuxRunnerIndex)
  endif
endfunction

function! VimuxPromptCommand(...)
  let command = a:0 == 1 ? a:1 : ""
  let l:command = input(_VimuxOption("g:VimuxPromptString", "Command? "), command)
  call VimuxRunCommand(l:command)
endfunction

function! _VimuxTmux(arguments)
  let l:command = _VimuxOption("g:VimuxTmuxCommand", "tmux")
  return system(l:command." ".a:arguments)
endfunction

function! _VimuxTmuxSession()
  return _VimuxTmuxProperty("#S")
endfunction

function! _VimuxTmuxIndex()
  if _VimuxRunnerType() == "pane"
    return _VimuxTmuxPaneIndex()
  else
    return _VimuxTmuxWindowIndex()
  end
endfunction

function! _VimuxTmuxPaneIndex()
  return _VimuxTmuxProperty("#I.#P")
endfunction

function! _VimuxTmuxWindowIndex()
  return _VimuxTmuxProperty("#I")
endfunction

function! _VimuxNearestIndex()
  let l:command = ''
  if exists("g:VimuxTargetSession")
    let l:command = "list-"._VimuxRunnerType()."s -t ".g:VimuxTargetSession
  else
    let l:command = "list-"._VimuxRunnerType()."s"
  endif

  let l:views = split(_VimuxTmux(l:command), "\n")

  for view in l:views
    if match(view, "(active)") == -1
      return split(view, ":")[0]
    endif
  endfor

  return -1
endfunction

function! _VimuxRunnerType()
  return _VimuxOption("g:VimuxRunnerType", "pane")
endfunction

function! _VimuxOption(option, default)
  if exists(a:option)
    return eval(a:option)
  else
    return a:default
  endif
endfunction

function! _VimuxTmuxProperty(property)
    return substitute(_VimuxTmux("display -p '".a:property."'"), '\n$', '', '')
endfunction

function! _VimuxHasRunner(index)
  if exists("g:VimuxTargetSession")
    return match(_VimuxTmux("list-"._VimuxRunnerType()."s -t ".g:VimuxTargetSession), a:index.":")
  else
    return match(_VimuxTmux("list-"._VimuxRunnerType()."s -a"), a:index.":")
  endif
endfunction
