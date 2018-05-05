# Provide a nice prompt if the terminal supports it.
if [ "$TERM" != "dumb" -o -n "$INSIDE_EMACS" ]; then
  GREEN="\033[0;32m"
  BLACK="\033[0;30m"
  BOLD="\033[1m"
  NORMAL="\033[0m"

  PS1="\n╭\[${BOLD}\]\w\[${NORMAL}\]\$(_git_ps1_)\[${NORMAL}\] \[${BLACK}\]\t\[${NORMAL}\]\n╰(\u)• "
  PS2=" ❯ "
  PS4=" + "

  _git_ps1_() {
    local color="${GREEN}"

    # __git_ps1 inserts the current git branch where %s is
    echo "$(__git_ps1 " (${color}%s${NORMAL})")"
  }

  if test "$TERM" = "xterm"; then
    PS1="\[\033]2;\h:\u:\w\007\]${PS1}"
  fi
fi
