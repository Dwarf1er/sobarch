#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Must load (and set $BLE_VERSION) before starship's init below, so starship
# registers its native ble.sh hook instead of a plain PROMPT_COMMAND string.
[[ -f /usr/share/blesh/ble.sh ]] && source -- /usr/share/blesh/ble.sh

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

command -v fastfetch >/dev/null && fastfetch
command -v starship >/dev/null && eval "$(starship init bash)"
command -v mise >/dev/null && eval "$(mise activate bash)"

# Use bash-completion, if available, and avoid double-sourcing
[[ $PS1 &&
  ! ${BASH_COMPLETION_VERSINFO:-} &&
  -f /usr/share/bash-completion/bash_completion ]] &&
    . /usr/share/bash-completion/bash_completion
