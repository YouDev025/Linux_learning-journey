# Bash Scripting Practice

A reference guide to writing reliable, reusable Bash scripts — control flow, input validation, exit codes, and debugging techniques.

---

## 📜 Script Fundamentals

### The Shebang Line

Every script should start with a **shebang** telling the system which interpreter to run it with:

```bash
#!/usr/bin/env bash
```

```bash
chmod +x myscript.sh      # make it executable (see the Permissions guide)
./myscript.sh                # run it
```

> **Tip:** Prefer `#!/usr/bin/env bash` over the more rigid `#!/bin/bash` — the `env` form finds `bash` wherever it happens to be in `$PATH`, which matters on systems where it isn't installed at the conventional path (some macOS setups, certain containers).

---

## 🔀 Conditionals: `if`

### Basic Syntax

```bash
if [ "$1" = "start" ]; then
    echo "Starting..."
elif [ "$1" = "stop" ]; then
    echo "Stopping..."
else
    echo "Unknown command"
fi
```

> **Spacing matters:** `[ ... ]` is actually a command (`test`), so it requires spaces around the brackets and around every operator inside it. `[$1=start]` will fail or behave unexpectedly — always write `[ "$1" = "start" ]`.

### `[ ]` vs `[[ ]]`

`[[ ]]` is a Bash-specific extension to the older, POSIX-compatible `[ ]` — more forgiving and capable, and generally preferred in scripts that don't need to run under a strict POSIX `sh`.

```bash
if [[ $name == "Alice" ]]; then     # [[ ]] doesn't require quoting $name to avoid word-splitting issues
    echo "Hi Alice"
fi

if [[ -f "$file" && -r "$file" ]]; then    # supports && / || directly, no need for -a / -o
    echo "File exists and is readable"
fi
```

### Common Test Operators

| Operator | Tests |
|---|---|
| `-f file` | File exists and is a regular file |
| `-d dir` | Directory exists |
| `-e path` | Path exists (any type) |
| `-r` / `-w` / `-x` | Readable / writable / executable |
| `-z string` | String is empty |
| `-n string` | String is non-empty |
| `=` / `==` | String equality |
| `!=` | String inequality |
| `-eq` / `-ne` | Numeric equality / inequality |
| `-lt` / `-le` / `-gt` / `-ge` | Numeric less-than / less-or-equal / greater-than / greater-or-equal |

```bash
if [ -f "/etc/passwd" ]; then echo "exists"; fi
if [ "$count" -gt 10 ]; then echo "more than 10"; fi
if [ -z "$name" ]; then echo "name is empty"; fi
```

> **Common mistake:** using `=`/`!=` for numbers, or `-eq`/`-gt` for strings. They're not interchangeable — `[ "10" -gt "9" ]` is true (numeric), but `[ "10" \> "9" ]` (string comparison) is actually false, since string comparison is lexicographic, not numeric.

---

## 🔀 Multi-Way Branching: `case`

`case` is often clearer than a long `if`/`elif` chain when matching one value against several possibilities, and it supports glob-style pattern matching directly.

```bash
case "$1" in
    start)
        echo "Starting service..."
        ;;
    stop)
        echo "Stopping service..."
        ;;
    restart|reload)
        echo "Restarting service..."
        ;;
    status)
        echo "Checking status..."
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
```

| Syntax element | Meaning |
|---|---|
| `pattern)` | Start of a match block |
| `;;` | End of that block (don't fall through to the next) |
| `a\|b)` | Match either pattern |
| `*)` | Catch-all default — matches anything not matched above |

```bash
case "$filename" in
    *.txt) echo "Text file" ;;
    *.jpg|*.png) echo "Image file" ;;
    *) echo "Unknown type" ;;
esac
```

---

## 🔁 Loops

### `for` — Iterating Over a List

```bash
for fruit in apple banana cherry; do
    echo "Fruit: $fruit"
done
```

```bash
for file in /var/log/*.log; do          # glob expansion — iterate over matching files
    echo "Processing $file"
done
```

```bash
for i in {1..5}; do                       # brace expansion — a numeric range
    echo "Number: $i"
done
```

```bash
for i in $(seq 1 2 10); do                 # seq for more control: start, step, end
    echo "$i"
done
```

### `while` — Looping on a Condition

```bash
count=1
while [ "$count" -le 5 ]; do
    echo "Count: $count"
    count=$((count + 1))
done
```

### Reading Input Line by Line: `while read`

The standard, safe pattern for processing a file line by line:

```bash
while IFS= read -r line; do
    echo "Line: $line"
done < input.txt
```

| Part | Why it's there |
|---|---|
| `IFS=` | Prevents leading/trailing whitespace from being trimmed off each line |
| `read -r` | Prevents backslashes in the input from being interpreted as escape sequences |
| `< input.txt` | Redirects the file as input to the whole loop |

> **Tip:** Always use `while IFS= read -r line`, not the bare `while read line` — without `IFS=` and `-r`, lines with leading spaces or backslashes get silently mangled.

### `until` — Looping Until a Condition Becomes True

```bash
count=1
until [ "$count" -gt 5 ]; do
    echo "Count: $count"
    count=$((count + 1))
done
```

### Loop Control: `break` and `continue`

```bash
for i in {1..10}; do
    if [ "$i" -eq 5 ]; then
        break          # exit the loop entirely
    fi
    echo "$i"
done
```

```bash
for i in {1..10}; do
    if [ $((i % 2)) -eq 0 ]; then
        continue         # skip to the next iteration
    fi
    echo "$i"             # only prints odd numbers
done
```

---

## ✅ Input Validation

### Checking Argument Count

```bash
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <source> <destination>" >&2
    exit 1
fi
```

| Variable | Meaning |
|---|---|
| `$#` | Number of arguments passed to the script |
| `$1`, `$2`, ... | Individual positional arguments |
| `$@` | All arguments, as separate words (preferred for most uses) |
| `$*` | All arguments, as a single combined string |
| `"$@"` | All arguments, EACH still properly quoted/separated — almost always what you want when looping |

### Validating Argument Content

```bash
source="$1"
dest="$2"

if [ ! -f "$source" ]; then
    echo "Error: source file '$source' does not exist" >&2
    exit 1
fi

if [ -z "$dest" ]; then
    echo "Error: destination cannot be empty" >&2
    exit 1
fi
```

### Validating Numeric Input

```bash
if ! [[ "$1" =~ ^[0-9]+$ ]]; then
    echo "Error: '$1' is not a valid positive integer" >&2
    exit 1
fi
```

### Reading Interactive Input

```bash
read -p "Enter your name: " name
echo "Hello, $name"

read -sp "Enter password: " password    # -s suppresses echoing input to the screen
echo                                       # print a newline, since -s suppresses that too
```

---

## 🚦 Exit Codes

### The Convention

By Unix convention, a script/command exits with `0` for success and any **non-zero** value (typically 1–255) to indicate some kind of failure — the specific non-zero value can encode different failure reasons.

```bash
exit 0      # success
exit 1       # generic error
exit 2        # often used for "incorrect usage" by convention, though not enforced
```

### Checking Exit Codes

```bash
some_command
if [ $? -eq 0 ]; then
    echo "Success"
else
    echo "Failed with exit code $?"     # NOTE: this $? is now the exit code of the `if`/echo itself — see below
fi
```

> ⚠️ **Common pitfall:** `$?` reflects the **most recently completed** command — if you run anything (even another `echo`) between the command you care about and checking `$?`, you've lost it. Capture it into a variable immediately if you need to reference it more than once:
> ```bash
> some_command
> exit_code=$?
> echo "Command exited with $exit_code"
> if [ "$exit_code" -ne 0 ]; then
>     echo "Failed!"
> fi
> ```

### Using Exit Codes in Conditionals Directly

Commands can be used directly as conditions — `if` checks the exit code automatically, with no explicit `$?` needed:

```bash
if grep -q "error" /var/log/app.log; then
    echo "Found an error in the log"
fi

if ! ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    echo "Host is unreachable"
fi
```

### Chaining on Success/Failure: `&&` and `||`

```bash
mkdir /tmp/work && cd /tmp/work          # cd only runs if mkdir succeeded
command1 || echo "command1 failed"         # echo only runs if command1 FAILED
mkdir -p /tmp/output || exit 1               # bail out immediately if this specific step fails
```

---

## 🐞 Debugging Scripts

### `set -e` — Exit Immediately on Any Error

```bash
#!/usr/bin/env bash
set -e

mkdir /tmp/work
cd /tmp/work
some_command_that_might_fail    # if this fails, the script stops immediately here
echo "This line never runs if the above failed"
```

> **Why this matters:** without `set -e`, a script keeps running line by line even after a command fails — silently producing wrong results downstream based on a step that never actually succeeded. `set -e` converts that into a clean, immediate stop.

> ⚠️ **Caveat:** `set -e` has well-known edge cases — it does **not** trigger inside conditions being tested (`if some_command; then`), inside most pipeline stages except the last (unless `set -o pipefail` is also set — see below), or inside functions called as part of a condition. Don't treat it as an absolute guarantee; test your specific script's failure paths.

### `set -u` — Error on Undefined Variables

```bash
set -u
echo "$undefined_variable"    # errors out instead of silently expanding to an empty string
```

This catches typos in variable names early — a misspelled `$fielname` instead of `$filename` fails loudly instead of silently treating it as empty.

### `set -o pipefail` — Catch Failures Inside Pipelines

```bash
set -o pipefail
some_command_that_fails | grep "something"
echo $?    # WITHOUT pipefail: reflects grep's exit code, even if some_command_that_fails actually failed
            # WITH pipefail: reflects the LAST command in the pipeline that actually failed
```

### The Common Combo: `set -euo pipefail`

```bash
#!/usr/bin/env bash
set -euo pipefail
```

This combination — informally nicknamed "strict mode" — is a common, defensive default for production scripts: stop on any error, stop on undefined variables, and don't let pipeline failures hide behind a later command's success.

### `set -x` — Trace Every Command as It Runs

```bash
#!/usr/bin/env bash
set -x

name="Alice"
echo "Hello, $name"
```

```
+ name=Alice
+ echo 'Hello, Alice'
Hello, Alice
```

Each line is printed (prefixed with `+`) **after variable expansion**, showing exactly what actually ran — invaluable for figuring out why a script is behaving unexpectedly, especially around quoting or variable content you assumed was correct.

### Toggling Tracing for Just Part of a Script

```bash
echo "Normal output"
set -x
echo "This line is traced: $some_var"
set +x                  # turn tracing back OFF
echo "Back to normal output"
```

### Running a Script in Debug Mode Without Editing It

```bash
bash -x myscript.sh         # trace the WHOLE script, without adding set -x inside it
bash -n myscript.sh          # syntax-check only — parse the script WITHOUT executing anything
```

### Other Useful Debugging Aids

```bash
echo "DEBUG: value of x is $x" >&2     # send debug output to stderr, keeping stdout clean for actual results
trap 'echo "Error on line $LINENO"' ERR   # print the line number whenever a command fails (with set -e)
```

---

## ⚡ Quick Reference

| Task | Syntax |
|---|---|
| Basic if/else | `if [ cond ]; then ... else ... fi` |
| Bash-extended test | `if [[ cond ]]; then ... fi` |
| Multi-way branch | `case "$var" in pattern) ... ;; esac` |
| Loop over a list | `for x in list; do ... done` |
| Loop on a condition | `while [ cond ]; do ... done` |
| Read a file line by line | `while IFS= read -r line; do ... done < file` |
| Check argument count | `if [ "$#" -lt N ]; then ... fi` |
| Check previous exit code | `exit_code=$?` |
| Exit with a status | `exit 0` (success) / `exit 1` (failure) |
| Stop on any error | `set -e` |
| Error on undefined variables | `set -u` |
| Catch pipeline failures | `set -o pipefail` |
| Trace every command | `set -x` |
| Syntax-check without running | `bash -n script.sh` |

---

## 💡 Best Practices

- Start every script with `#!/usr/bin/env bash` and, for anything beyond a trivial one-liner, `set -euo pipefail` right after it.
- Always quote variable expansions (`"$var"`, `"$@"`) inside conditionals and loops — unquoted expansion is the single most common source of script bugs, especially with filenames containing spaces.
- Validate argument count and content early, and exit with a clear usage message (to `stderr`, via `>&2`) and a non-zero exit code when input is invalid.
- Capture `$?` into a variable immediately if you need to check it more than once — running anything else first overwrites it.
- Use `while IFS= read -r line` for reading files line by line — the bare `while read line` form mishandles whitespace and backslashes.
- Reach for `bash -x script.sh` (rather than editing in `set -x`) for a quick one-off debug run without modifying the script itself.
- Remember `set -e`'s edge cases (conditions, non-final pipeline stages) — pair it with `pipefail` and don't treat it as catching literally every possible failure mode unconditionally.
- Prefer `case` over a long `if`/`elif` chain when matching one variable against several discrete possibilities — it's more readable and supports glob patterns natively.