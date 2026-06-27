# Shell Basics

A reference guide to working efficiently in the Linux shell — interactive productivity features, startup configuration files, and the fundamentals of variables, quoting, and command substitution.

---

## 🐚 What the Shell Actually Does

The shell is a program that reads commands you type, interprets them, and asks the kernel to execute them — it's the layer between you and the operating system's actual functionality. Bash is the default shell on most Linux distributions, though others (`zsh`, `fish`, `dash`) exist with different feature sets and syntax variations; this guide focuses on Bash, since it's the most universal baseline.

```bash
echo $0          # show which shell is currently running
echo $SHELL       # show your configured default login shell
```

---

## ⌨️ Interactive Shell Productivity

### Tab Completion

Pressing `Tab` completes commands, filenames, and arguments automatically — one of the single biggest speed and accuracy improvements available in everyday shell use.

```bash
cd /ho<Tab>            # completes to /home/ (or further, if unambiguous)
ls /var/lo<Tab>          # completes to /var/log/
sudo apt ins<Tab>          # many tools support completing SUBCOMMANDS too, not just paths
```

Pressing `Tab` twice when there are multiple possible matches shows all of them:

```bash
ls /etc/cr<Tab><Tab>
cron.d/  cron.daily/  cron.hourly/  crontab
```

> **Tip:** Tab completion isn't just convenient — it's a built-in error check. If a path or command doesn't complete the way you expect, that's often your first sign of a typo before you've even pressed Enter.

### Command History

Bash remembers previously run commands, retrievable and searchable without retyping them.

```bash
history                  # list recent command history
history 20                 # show just the last 20
!42                          # re-run history entry number 42
!!                            # re-run the PREVIOUS command
!ls                            # re-run the most recent command starting with "ls"
```

| Keystroke | Action |
|---|---|
| `↑` / `↓` | Step backward/forward through history |
| `Ctrl+R` | Incremental reverse search — type to search history live |
| `Ctrl+G` | Cancel a `Ctrl+R` search |
| `Ctrl+A` / `Ctrl+E` | Jump to start / end of the current line |
| `Ctrl+U` | Clear from cursor to start of line |
| `Ctrl+K` | Clear from cursor to end of line |
| `Ctrl+L` | Clear the screen (same as `clear`) |

```bash
history | grep ssh        # search history for a specific past command
```

### Where History Is Stored

```bash
cat ~/.bash_history       # raw history file (only updated when the shell exits, by default)
echo $HISTSIZE              # how many commands are kept in memory per session
echo $HISTFILESIZE           # how many are kept in the history FILE
```

> **Note:** By default, history is only written to `~/.bash_history` when the shell session ends cleanly — commands from a still-open session aren't yet in the file. Set `shopt -s histappend` and `PROMPT_COMMAND="history -a"` (commonly placed in `.bashrc`) if you want history written immediately and shared live across multiple open terminals.

### Useful Shortcuts and Tricks

```bash
cd -                  # jump back to the previous directory
!$                      # the LAST argument of the previous command
!*                       # ALL arguments of the previous command
sudo !!                  # re-run the previous command, with sudo prepended — handy after a "permission denied"
```

```bash
$ apt install nginx
Permission denied
$ sudo !!
sudo apt install nginx     # bash shows you what it's about to run, then runs it
```

---

## 🗂️ Shell Startup Files: `.bashrc` and `.profile`

Bash reads different configuration files depending on **how** the shell was started — this distinction trips up a lot of people, so it's worth understanding clearly.

### Login Shell vs. Non-Login, Interactive vs. Non-Interactive

| Shell type | When it happens | Files read |
|---|---|---|
| **Login, interactive** | SSH login, console login, `bash --login` | `/etc/profile`, then the first of `~/.bash_profile`, `~/.bash_login`, or `~/.profile` |
| **Non-login, interactive** | Opening a new terminal window/tab in a desktop environment | `~/.bashrc` |
| **Non-interactive** | Running a script | `$BASH_ENV`, if set (rarely used) |

### `.bashrc` — Per-Terminal Interactive Setup

Read every time you open a **new interactive shell** that isn't a fresh login (e.g. opening a new terminal tab). This is where most day-to-day customization belongs:

```bash
# ~/.bashrc
alias ll='ls -la'
alias gs='git status'
export PS1='\u@\h:\w\$ '     # customize the prompt
PATH="$HOME/bin:$PATH"
```

### `.profile` / `.bash_profile` — Login Setup

Read once, at **login** — intended for things that should be set up exactly once per session, not re-applied every time you open a new terminal tab (environment variables, particularly `PATH` additions, are the classic example, since re-prepending the same directory to `PATH` on every new tab would otherwise cause it to grow redundantly over a long session).

```bash
# ~/.profile
export EDITOR=vim
export PATH="$HOME/.local/bin:$PATH"

# A common pattern: have .bash_profile ALSO load .bashrc,
# so login shells get your interactive customizations too:
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
```

### Why the Split Exists, Practically

Most desktop terminal emulators open **non-login** shells (you already logged into the desktop session itself once) — meaning `.bashrc` is what actually runs for most "open a new terminal" actions day to day, while `.profile`/`.bash_profile` matters more for SSH sessions, console logins, or explicit `bash --login` invocations.

> **Tip:** If something works when you SSH in but not when you open a local terminal (or vice versa), this login/non-login distinction is almost always the cause — check which file actually defines the thing that's "missing."

### Reloading Configuration Without Restarting

```bash
source ~/.bashrc        # re-read and apply .bashrc in the CURRENT shell
. ~/.bashrc               # "." is a shorthand alias for "source"
```

---

## 🧮 Variables

### Setting and Using Variables

```bash
name="Alice"             # NO spaces around the = sign
echo $name                 # use a variable
echo "${name}"               # braces are clearer, especially when adjacent to other text
echo "${name}_smith"          # braces are NECESSARY here — $name_smith would look for a variable literally named "name_smith"
```

### Environment Variables vs. Shell Variables

A **shell variable** is local to the current shell session. An **environment variable** is also passed down to any child processes the shell launches.

```bash
my_var="local only"             # shell variable — NOT visible to child processes
export my_env_var="visible to children"   # environment variable — IS passed down
```

```bash
env                    # list all current environment variables
printenv PATH            # show one specific environment variable
unset my_env_var          # remove a variable entirely
```

### Common Built-In Environment Variables

| Variable | Meaning |
|---|---|
| `$HOME` | Current user's home directory |
| `$PATH` | Directories searched, in order, when you type a command name |
| `$USER` | Current username |
| `$PWD` | Current working directory |
| `$SHELL` | Path to the user's default shell |
| `$?` | Exit status of the LAST command run (`0` = success, non-zero = error) |
| `$$` | PID of the current shell |
| `$0` | Name of the current script/shell itself |

```bash
echo $PATH
# /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/home/alice/bin
```

```bash
ls /nonexistent
echo $?         # check the exit status of the PREVIOUS command — non-zero means it failed
```

---

## 🔤 Quoting

Quoting controls how the shell interprets special characters (`$`, spaces, `*`, etc.) within a string — getting this wrong is one of the most common sources of subtle scripting bugs.

### Double Quotes `"..."`

Variables and command substitution are still **expanded** inside double quotes, but spaces/globbing are preserved literally.

```bash
name="Alice"
echo "Hello, $name"            # Hello, Alice  — variable IS expanded
echo "Files: *.txt"              # Files: *.txt  — literal asterisk, NOT expanded as a glob
```

### Single Quotes `'...'`

**Nothing** is expanded inside single quotes — everything is taken completely literally, including variables.

```bash
echo 'Hello, $name'             # Hello, $name  — NOT expanded, printed literally
```

### No Quotes

Without quotes, the shell performs **word splitting** (breaking on spaces) and **globbing** (expanding `*`, `?`, etc.) — often not what you want for variables that might contain spaces or special characters.

```bash
file="my document.txt"
cat $file              # BROKEN: shell splits this into TWO arguments: "my" and "document.txt"
cat "$file"             # CORRECT: treated as ONE argument, exactly as intended
```

> **Rule of thumb:** quote your variables (`"$var"`) by default, almost everywhere — unquoted variable expansion is one of the most common sources of shell scripting bugs, especially with filenames containing spaces.

### Escaping Individual Characters

```bash
echo "Cost: \$5"          # Cost: $5  — backslash escapes the $ specifically, even inside double quotes
echo \$HOME                  # $HOME  — escapes outside quotes too, preventing expansion
```

---

## 🔁 Command Substitution

Command substitution runs a command and **substitutes its output** directly into another command or variable assignment.

### Modern Syntax: `$(...)`

```bash
current_dir=$(pwd)
echo "You are in: $(pwd)"
files=$(ls /etc | wc -l)
echo "There are $files files in /etc"
```

### Legacy Syntax: Backticks `` `...` ``

```bash
current_dir=`pwd`        # equivalent to $(pwd), but harder to read and nest
```

> **Tip:** Prefer `$(...)` over backticks in virtually all cases — it's easier to read, and critically, it **nests cleanly**, while backticks require awkward escaping to nest:
> ```bash
> echo $(echo $(echo "nested"))     # works cleanly
> echo `echo \`echo "nested"\``       # works, but is much harder to read and write correctly
> ```

### Combining with Quoting

```bash
echo "Today is $(date +%A)"           # command substitution still works inside double quotes
result="Found $(ls *.txt | wc -l) files"
```

### Practical Example

```bash
backup_name="backup_$(date +%Y-%m-%d).tar.gz"
tar -czvf "$backup_name" /home/alice/documents
echo "Created $backup_name"
```

---

## ⚡ Quick Reference

| Task | Command / Keystroke |
|---|---|
| Complete a command/path | `Tab` |
| Show ambiguous completions | `Tab` `Tab` |
| Search command history live | `Ctrl+R` |
| Re-run last command | `!!` |
| Re-run with sudo prepended | `sudo !!` |
| Last argument of previous command | `!$` |
| Reload `.bashrc` | `source ~/.bashrc` |
| Set a shell variable | `name="value"` (no spaces around `=`) |
| Make a variable an environment variable | `export name="value"` |
| Check previous command's exit status | `echo $?` |
| Substitute a command's output | `$(command)` |
| Quote a variable safely | `"$variable"` |

---

## 💡 Best Practices

- Quote variables (`"$var"`) by default — unquoted expansion is a leading cause of scripts breaking on filenames with spaces or special characters.
- Prefer `$(...)` over backticks for command substitution — it's more readable and nests without awkward escaping.
- Put interactive customizations (aliases, prompt, `PATH` tweaks you want active in every terminal) in `.bashrc`; reserve `.profile`/`.bash_profile` for things that should run once per login.
- If `.bash_profile` exists, have it source `.bashrc` too — otherwise login shells (like SSH sessions) won't pick up your everyday interactive customizations.
- Use `Ctrl+R` instead of scrolling through history with the up arrow for anything more than a few commands back — it's dramatically faster once it becomes muscle memory.
- Check `$?` immediately after a command when scripting conditionals on success/failure — it reflects only the *immediately preceding* command, so don't run anything else (even `echo`) in between if you need that specific exit code.
- Remember the login/non-login distinction when something "works over SSH but not in a local terminal" (or vice versa) — it's almost always which startup file actually ran.