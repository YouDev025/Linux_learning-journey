# Functions and Variables

A reference guide to structuring Bash scripts with functions — defining and calling them, scoping variables, handling arguments, and managing environment variables and shell options.

---

## 🧱 Defining and Calling Functions

### Basic Syntax

Two equivalent styles exist; both are common in real-world scripts:

```bash
greet() {
    echo "Hello, World!"
}

function greet2 {
    echo "Hello again!"
}
```

```bash
greet            # call it like any other command — no parentheses at the call site
greet2
```

> **Tip:** The `name() { ... }` form is POSIX-compatible and works in `sh` as well as `bash`. The `function name { ... }` form is a Bash-specific extension. Prefer the first style unless you have a specific reason not to — it's portable to more environments.

### Functions Must Be Defined Before They're Called

Bash reads a script top to bottom — a function has to be **defined** before the point in the script where you call it, exactly like a variable has to be set before you can read it.

```bash
greet           # ERROR: greet isn't defined yet at this point in the script

greet() {
    echo "Hello!"
}
```

```bash
greet() {
    echo "Hello!"
}

greet           # WORKS: defined above before being called
```

### Returning a Value vs. Returning an Exit Code

This is a common point of confusion: Bash functions don't "return" data the way functions do in most other languages — `return` sets the function's **exit code** (0–255 only), not an arbitrary value.

```bash
is_even() {
    if [ $(( $1 % 2 )) -eq 0 ]; then
        return 0      # success / "true"
    else
        return 1       # failure / "false"
    fi
}

if is_even 4; then
    echo "4 is even"
fi
```

To actually return **data** (a string, a number outside 0-255, computed output), use `echo` and capture it with command substitution instead:

```bash
get_greeting() {
    echo "Hello, $1!"        # this is "returned" by being printed, not via `return`
}

message=$(get_greeting "Alice")
echo "$message"
```

> **Rule of thumb:** use `return` (0/non-zero) when the function's job is a yes/no success-or-failure check. Use `echo` + command substitution when the function's job is to produce a value the caller needs to use.

---

## 📥 Function Arguments and Positional Parameters

### Arguments Inside a Function

Functions receive their own set of positional parameters (`$1`, `$2`, ...), separate from the script's own — calling a function doesn't expose the script's `$1` inside the function unless you explicitly pass it.

```bash
greet_person() {
    echo "Hello, $1! You are $2 years old."
}

greet_person "Alice" 30
# Hello, Alice! You are 30 years old.
```

| Inside a function | Meaning |
|---|---|
| `$1`, `$2`, ... | This function's own arguments |
| `$#` | Number of arguments passed TO this function |
| `$@` | All of this function's arguments, as separate words |
| `"$@"` | Same, but each argument preserved/quoted correctly — almost always what you want |
| `$0` | Still the SCRIPT's name, not the function's name (functions don't get their own `$0`) |

### Passing the Script's Own Arguments Through to a Function

```bash
process_args() {
    echo "Received $# arguments: $*"
}

process_args "$@"      # forward ALL of the script's own arguments into the function, properly quoted
```

> **Why `"$@"` and not `$@` or `$*`:** unquoted `$@`/`$*` and quoted `"$*"` all mangle arguments containing spaces by re-splitting or merging them incorrectly. `"$@"` is the only form that reliably preserves each original argument as its own distinct unit — see the *Bash Scripting Practice* guide for more on quoting pitfalls generally.

### Default Values for Missing Arguments

```bash
greet_person() {
    local name="${1:-stranger}"      # use "stranger" if $1 wasn't provided
    echo "Hello, $name!"
}

greet_person            # Hello, stranger!
greet_person "Bob"        # Hello, Bob!
```

---

## 🔒 Variable Scope: `local`

### The Default: Everything Is Global

Without `local`, a variable set inside a function is **global** — visible and modifiable from outside the function too, which can cause confusing, hard-to-trace bugs as scripts grow.

```bash
count=10

increment() {
    count=$((count + 1))     # modifies the GLOBAL $count — probably not intended
}

increment
echo "$count"     # 11 — changed, even though we just called a function
```

### Using `local` to Scope a Variable to the Function

```bash
count=10

increment() {
    local count=0              # this is now a SEPARATE, function-local variable
    count=$((count + 1))
    echo "Inside function: $count"
}

increment             # Inside function: 1
echo "$count"          # 10 — UNCHANGED, the global was never touched
```

> **Best practice:** declare every variable you don't specifically intend to expose globally as `local`, as the very first thing you do with it inside a function. This is one of the single highest-value habits for writing maintainable shell scripts of any real size.

### `local` with Command Substitution: A Common Gotcha

```bash
get_status() {
    local result=$(some_command)    # WORKS, but see below
    echo "$result"
}
```

```bash
get_status() {
    local result
    result=$(some_command)            # SAFER: declare and assign separately
    echo "$result"
}
```

> **Why separate is safer:** combining `local` and command substitution on one line can mask the exit code of the substituted command — `$?` immediately after ends up reflecting `local`'s own (always-zero) exit status, not `some_command`'s. Splitting the declaration from the assignment avoids this if you need to check the exit code.

---

## 🌐 Exported Environment Variables

### Shell Variable vs. Environment Variable, Revisited

As covered in the *Shell Basics* guide, a plain shell variable is local to the current shell; `export` promotes it to an **environment variable**, which is also passed down to any child processes (including functions calling external commands, and scripts calling other scripts).

```bash
api_key="abc123"              # shell variable only — NOT visible to a script this one calls
export api_key="abc123"        # environment variable — IS visible to child processes
```

```bash
# parent.sh
export GREETING="Hello from parent"
./child.sh
```

```bash
# child.sh
echo "$GREETING"      # Hello from parent — inherited because parent exported it
```

### Functions and Exported Variables

A function defined in the current shell **is** part of the current shell — it automatically sees any exported (or even non-exported) variable already in scope, no special passing required:

```bash
export region="us-east-1"

show_region() {
    echo "Region: $region"     # sees it directly — functions share the calling shell's scope
}

show_region
```

But if that function then calls an **external program or separate script**, only `export`-ed variables make it through:

```bash
export region="us-east-1"
local_only="not exported"

show_via_subshell() {
    bash -c 'echo "Region: $region"'           # WORKS: region was exported
    bash -c 'echo "Local: $local_only"'          # EMPTY: local_only was never exported
}
```

### Checking and Managing Exported Variables

```bash
export -p              # list all currently exported variables
declare -p my_var        # show how a specific variable is currently declared (exported or not, etc.)
export -n my_var          # remove the export attribute, without unsetting the variable's value
unset my_var               # remove the variable entirely
```

---

## ⚙️ Shell Options

Shell options (`set`, `shopt`) change how Bash itself behaves — distinct from variables, which hold data.

### `set` — POSIX-Standard Options

Covered in depth in the *Bash Scripting Practice* guide; the most common in everyday scripts:

```bash
set -e          # exit immediately on any unhandled error
set -u           # error on undefined variables
set -x            # trace every command as it executes
set -o pipefail    # propagate failure through pipelines, not just the last command
```

```bash
set +e          # turn an option back OFF (note: + disables, - enables)
```

### `shopt` — Bash-Specific Options

`shopt` controls Bash-only behaviors that go beyond the POSIX-standard `set` options.

```bash
shopt -s globstar        # enable ** to match directories recursively
shopt -s nullglob          # make a glob with no matches expand to NOTHING, instead of the literal pattern
shopt -s histappend         # append to history file instead of overwriting it (see the Shell Basics guide)
shopt -s nocaseglob          # case-insensitive globbing
```

```bash
shopt | grep globstar     # check the current state of a specific option
shopt -u globstar            # turn it back off ("-u" = unset)
```

### Why `nullglob` Matters in Scripts

Without it, a glob that matches nothing expands to the **literal pattern text itself** — a frequent source of confusing bugs:

```bash
# without nullglob, if no .txt files exist:
for file in *.txt; do
    echo "$file"        # prints the LITERAL string "*.txt" — there's no file actually named that!
done
```

```bash
shopt -s nullglob
for file in *.txt; do
    echo "$file"          # with no matches, the loop body simply never runs — correct behavior
done
```

---

## 🧩 Practical Example: Combining Everything

```bash
#!/usr/bin/env bash
set -euo pipefail

# Function with a default argument and local scoping
log_message() {
    local level="${1:-INFO}"
    local message="${2:-}"

    if [ -z "$message" ]; then
        echo "Error: log_message requires a message" >&2
        return 1
    fi

    echo "[$level] $message"
}

# Function that returns DATA via echo + command substitution
get_timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

# Function that returns a STATUS via return code
check_disk_space() {
    local threshold="${1:-90}"
    local usage
    usage=$(df / | awk 'NR==2 {print $5}' | tr -d '%')

    if [ "$usage" -ge "$threshold" ]; then
        return 1
    else
        return 0
    fi
}

main() {
    local timestamp
    timestamp=$(get_timestamp)

    log_message "INFO" "Script started at $timestamp"

    if check_disk_space 90; then
        log_message "INFO" "Disk space OK"
    else
        log_message "WARNING" "Disk space critically low"
    fi
}

main "$@"
```

> **Note the pattern at the bottom:** defining a `main` function and calling it with `main "$@"` as the very last line is a common, readable convention for scripts of any real size — it keeps top-level execution flow in one place and makes the script easier to read top-down.

---

## ⚡ Quick Reference

| Task | Syntax |
|---|---|
| Define a function (POSIX-compatible) | `name() { ... }` |
| Define a function (Bash-specific) | `function name { ... }` |
| Call a function | `name arg1 arg2` |
| Return a status code | `return 0` / `return 1` |
| "Return" a value | `echo "value"` + capture with `$(name ...)` |
| Function's own arguments | `$1`, `$2`, `$#`, `"$@"` |
| Forward script args into a function | `name "$@"` |
| Default value for an argument | `"${1:-default}"` |
| Scope a variable to the function | `local varname=value` |
| Make a variable inherited by child processes | `export varname=value` |
| List exported variables | `export -p` |
| Remove export without unsetting | `export -n varname` |
| Set a POSIX shell option | `set -e` / `set -u` / `set -o pipefail` |
| Set a Bash-specific option | `shopt -s optionname` |

---

## 💡 Best Practices

- Declare every function-internal variable with `local` unless you specifically intend it to be global — this single habit prevents a large share of confusing scripting bugs as scripts grow.
- Use `return` for success/failure signals; use `echo` + command substitution when a function needs to hand back actual data.
- Always forward arguments with `"$@"`, never bare `$@` or `$*` — it's the only form that survives arguments containing spaces intact.
- Separate `local varname` from its assignment (`varname=$(...)`) on two lines when you need to check the command's exit code afterward — combining them on one line masks `$?`.
- Provide default values for optional arguments with `"${1:-default}"` rather than letting an unset positional parameter silently propagate as empty.
- Enable `shopt -s nullglob` in scripts that loop over glob patterns which might match nothing — without it, a no-match glob expands to its own literal pattern text, which is rarely what you want.
- Adopt the `main "$@"` convention for any script beyond a few lines — it keeps execution order readable and makes the script easier to extend later.