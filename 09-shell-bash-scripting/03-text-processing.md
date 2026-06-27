# Text Processing

A reference guide to Linux's core text-processing toolkit — searching, transforming, and analyzing data from files and command output, plus the piping and redirection patterns that connect them.

---

## 🔗 Piping and Redirection: The Foundation

### Pipes: Chaining Commands Together

A pipe (`|`) sends one command's **stdout** directly into the next command's **stdin**, without an intermediate file — this is the core idea that makes all the tools below composable.

```bash
cat access.log | grep "ERROR" | wc -l
```

```
cat access.log    →   grep "ERROR"   →   wc -l
(prints file)          (filters lines)     (counts lines)
```

### The Three Standard Streams

| Stream | Number | Default destination |
|---|---|---|
| `stdin` | 0 | Keyboard / previous command's output |
| `stdout` | 1 | Terminal |
| `stderr` | 2 | Terminal (separate from stdout, even though both display there by default) |

### Redirection

```bash
command > output.txt           # redirect stdout, OVERWRITING the file
command >> output.txt            # redirect stdout, APPENDING to the file
command 2> errors.txt              # redirect stderr only
command > output.txt 2>&1            # redirect BOTH stdout and stderr to the same file
command &> output.txt                 # shorthand for the line above, in Bash
command < input.txt                     # use a file as stdin instead of the keyboard
command 2>/dev/null                      # discard stderr entirely (send it to the "void")
```

> **Order matters with `2>&1`:** `command > file 2>&1` works (stdout goes to the file, then stderr is redirected to wherever stdout NOW points — the file). `command 2>&1 > file` does **not** do the same thing (stderr is redirected to wherever stdout points *at that moment*, which is still the terminal, and only stdout goes to the file afterward).

### `tee` — Redirect and Still See Output

```bash
command | tee output.txt              # write to a file AND still print to the terminal
command | tee -a output.txt              # append instead of overwrite
sudo command | tee output.txt              # commonly needed when redirecting to a file requiring sudo, since the REDIRECT itself doesn't run as root, but tee can
```

---

## 🔍 `grep` — Searching Text

`grep` searches input for lines matching a pattern.

```bash
grep "error" logfile.txt                 # lines containing "error"
grep -i "error" logfile.txt                # case-insensitive
grep -v "debug" logfile.txt                 # INVERT: lines that do NOT match
grep -c "error" logfile.txt                  # COUNT matching lines, instead of printing them
grep -n "error" logfile.txt                    # show line NUMBERS alongside matches
grep -r "TODO" ./src/                            # RECURSIVELY search a directory tree
grep -l "TODO" *.py                                # list only FILENAMES that contain a match, not the lines
```

### Context Flags

```bash
grep -A 3 "error" logfile.txt         # show 3 lines AFTER each match
grep -B 3 "error" logfile.txt          # show 3 lines BEFORE each match
grep -C 3 "error" logfile.txt           # show 3 lines of CONTEXT on both sides
```

### Regular Expressions with `grep`

```bash
grep -E "error|warning" logfile.txt        # extended regex — alternation without escaping
grep "^ERROR" logfile.txt                    # lines STARTING WITH "ERROR" (^ = start of line)
grep "failed$" logfile.txt                     # lines ENDING WITH "failed" ($ = end of line)
grep -E "[0-9]{3}-[0-9]{4}" logfile.txt           # a simple phone-number-like pattern
```

| Flag | Meaning |
|---|---|
| `-i` | Case-insensitive |
| `-v` | Invert match (show non-matching lines) |
| `-c` | Count matches instead of showing them |
| `-n` | Show line numbers |
| `-r` / `-R` | Recursive directory search |
| `-l` | List matching filenames only |
| `-E` | Extended regex (supports `\|`, `{n,m}` without backslash-escaping) |
| `-o` | Print only the matched portion of each line, not the whole line |

---

## 🔧 `sed` — Stream Editing

`sed` ("stream editor") transforms text line by line, most commonly for find-and-replace operations.

### Basic Substitution

```bash
sed 's/old/new/' file.txt           # replace the FIRST occurrence per line
sed 's/old/new/g' file.txt            # replace ALL occurrences per line (g = global)
sed 's/old/new/gi' file.txt             # global AND case-insensitive
```

```bash
sed 's/old/new/' file.txt > newfile.txt     # output to a different file (sed doesn't modify in place by default)
sed -i 's/old/new/g' file.txt                  # edit the file IN PLACE — be careful, no undo
sed -i.bak 's/old/new/g' file.txt                # in-place, but keep a backup as file.txt.bak first
```

> ⚠️ **Caution:** `sed -i` modifies the file directly and irreversibly, with no confirmation. Test your expression without `-i` first (or with `-i.bak` to keep a backup) before running it on anything you can't easily recreate.

### Line-Based Operations

```bash
sed -n '5p' file.txt                  # print only line 5 ( -n suppresses normal auto-print)
sed -n '5,10p' file.txt                 # print lines 5 through 10
sed '5d' file.txt                        # delete line 5
sed '/pattern/d' file.txt                  # delete any line matching a pattern
sed -n '/start/,/end/p' file.txt             # print everything between two pattern matches, inclusive
```

### Using a Different Delimiter

When your search/replace text contains `/` itself (e.g. file paths), switch the delimiter to avoid a wall of backslashes:

```bash
sed 's/\/old\/path/\/new\/path/' file.txt     # awkward — every / needs escaping
sed 's#/old/path#/new/path#' file.txt           # cleaner — # as the delimiter instead
```

### Capture Groups

```bash
sed -E 's/([0-9]+)-([0-9]+)/\2-\1/' file.txt    # swap two captured number groups
```

---

## 📊 `awk` — Pattern Scanning and Field Processing

`awk` treats each line as a record split into **fields**, making it especially powerful for structured/columnar text (logs, CSVs, command output).

### Basic Field Access

```bash
echo "Alice 30 Engineer" | awk '{print $1}'        # Alice — first field
echo "Alice 30 Engineer" | awk '{print $2, $3}'      # 30 Engineer
echo "Alice 30 Engineer" | awk '{print $NF}'           # Engineer — NF = Number of Fields, so $NF = LAST field
```

By default, `awk` splits fields on **whitespace** — change this with `-F` for other delimiters:

```bash
awk -F: '{print $1}' /etc/passwd            # split on ":" — print just usernames
awk -F, '{print $2}' data.csv                  # split on "," for a CSV
```

### Patterns and Conditions

```bash
awk '/error/ {print}' logfile.txt                  # print lines matching a pattern (like grep, but composable with field logic)
awk '$3 > 100 {print $1}' data.txt                    # print field 1, but ONLY for lines where field 3 > 100
awk 'NR == 1 {print}' file.txt                          # NR = current line/record Number — print just the first line
awk 'NR > 1 {print}' file.txt                             # skip the first line (e.g. skip a CSV header)
```

### Built-In Variables

| Variable | Meaning |
|---|---|
| `$0` | The entire current line |
| `$1`, `$2`, ... | Individual fields |
| `NF` | Number of fields in the current line |
| `NR` | Current line/record number (across the whole input) |
| `FS` | Field separator (input) |
| `OFS` | Output field separator |

### Computation and Aggregation

```bash
awk '{sum += $1} END {print sum}' numbers.txt           # sum a column of numbers
awk '{sum += $1; count++} END {print sum/count}' numbers.txt   # compute an average
awk -F, '{print $2}' data.csv | sort | uniq -c             # combine awk with other tools for a frequency count
```

```bash
awk 'BEGIN {print "Starting"} {print} END {print "Done"}' file.txt
```

`BEGIN` runs once before any input is read; the main block runs **once per line**; `END` runs once after all input is processed — this three-part structure is the core mental model for `awk`.

### Reformatting Output

```bash
awk '{print $2, $1}' file.txt                  # swap field order
awk 'BEGIN {OFS=","} {print $1, $2}' file.txt    # join fields back together with a custom separator
```

---

## ✂️ `cut` — Extracting Fixed Columns/Fields

`cut` is a simpler, faster alternative to `awk` when you just need specific delimited fields or character positions, with no conditions or computation.

```bash
cut -d: -f1 /etc/passwd               # field 1, delimiter ":"
cut -d, -f2,4 data.csv                  # fields 2 AND 4, delimiter ","
cut -d, -f2-4 data.csv                   # fields 2 THROUGH 4 (a range)
cut -c1-10 file.txt                        # CHARACTERS 1 through 10, regardless of delimiters
```

| Flag | Meaning |
|---|---|
| `-d` | Delimiter character |
| `-f` | Field number(s) — supports `N`, `N,M`, or `N-M` |
| `-c` | Character position(s), instead of delimited fields |

> **`cut` vs `awk`:** reach for `cut` when you just need "give me column N" with no logic involved — it's simpler to write and faster on large files. Reach for `awk` as soon as you need a condition, computation, or output reformatting.

---

## 🔢 `sort` and `uniq` — Ordering and Deduplication

### `sort`

```bash
sort file.txt                  # alphabetical sort
sort -r file.txt                 # REVERSE order
sort -n numbers.txt                # NUMERIC sort (default sort is lexicographic — "10" sorts before "9" otherwise!)
sort -k2 data.txt                    # sort by the 2nd field/column specifically
sort -t, -k2,2n data.csv               # CSV: sort by field 2, treating it as numeric
sort -u file.txt                         # sort AND remove duplicate lines in one step
```

> **Common pitfall:** without `-n`, `sort` compares lines as text, so `"10"` sorts *before* `"9"` (because `"1"` < `"9"` as the first character). Always use `-n` when sorting numbers, including version-like strings.

### `uniq`

`uniq` removes (or reports on) **adjacent** duplicate lines — it does not deduplicate across an entire unsorted file, which is why it's almost always paired with `sort` first.

```bash
sort file.txt | uniq                # remove duplicate lines (sort FIRST, since uniq only catches ADJACENT dupes)
sort file.txt | uniq -c               # count occurrences of each unique line
sort file.txt | uniq -d                # show ONLY lines that had duplicates
sort file.txt | uniq -u                 # show ONLY lines that were unique (no duplicates at all)
```

```bash
sort access.log | awk '{print $1}' | sort | uniq -c | sort -rn | head -10
# a classic combo: extract a field, count occurrences, sort by frequency, show top 10
```

---

## 🔄 `tr` — Translating/Deleting Characters

`tr` operates on individual **characters**, not lines or fields — useful for simple character-level substitutions and cleanup.

```bash
echo "hello" | tr 'a-z' 'A-Z'             # HELLO — translate lowercase to uppercase
echo "hello world" | tr ' ' '_'              # hello_world — replace spaces with underscores
echo "hello123world" | tr -d '0-9'             # hello world → helloworld — DELETE all digits
echo "a   b    c" | tr -s ' '                    # SQUEEZE repeated spaces down to one each
```

| Flag | Meaning |
|---|---|
| `-d` | Delete the specified characters |
| `-s` | Squeeze repeated occurrences into one |
| `-c` | Complement — operate on characters NOT in the set |

```bash
cat file.txt | tr -d '\r'                   # strip Windows-style carriage returns (common Windows→Linux text fix)
```

---

## 🧩 Combining Tools: Practical Pipelines

```bash
# Top 10 most frequent IP addresses in a web server log
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -10

# Count how many lines in a CSV have a specific value in column 3
awk -F, '$3 == "active"' data.csv | wc -l

# Extract unique error messages, alphabetically
grep "ERROR" app.log | cut -d: -f3- | sort -u

# Replace tabs with commas, then extract the second field
cat data.tsv | tr '\t' ',' | cut -d, -f2

# Find the 5 largest files in a directory, human-readable
du -ah . | sort -rh | head -5
```

> **Tip:** Building a pipeline incrementally — running each stage alone first, checking its output, then piping into the next — is far more reliable than writing a five-stage pipeline blind and debugging it as a whole afterward.

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| Search for a pattern | `grep "pattern" file` |
| Case-insensitive search | `grep -i "pattern" file` |
| Count matching lines | `grep -c "pattern" file` |
| Recursive search | `grep -r "pattern" dir/` |
| Find and replace (in place) | `sed -i 's/old/new/g' file` |
| Print specific lines | `sed -n '5,10p' file` |
| Print a field (whitespace) | `awk '{print $1}' file` |
| Print a field (custom delimiter) | `awk -F, '{print $2}' file` |
| Sum a column | `awk '{sum+=$1} END {print sum}' file` |
| Extract a delimited field | `cut -d, -f2 file` |
| Sort numerically | `sort -n file` |
| Sort and deduplicate | `sort -u file` |
| Count occurrences of each line | `sort file \| uniq -c` |
| Translate characters | `tr 'a-z' 'A-Z'` |
| Delete characters | `tr -d '0-9'` |
| Redirect stdout (overwrite) | `command > file` |
| Redirect stdout + stderr | `command > file 2>&1` |
| Redirect and still see output | `command \| tee file` |

---

## 💡 Best Practices

- Build multi-stage pipelines incrementally — verify each stage's output before adding the next, rather than debugging a long pipeline all at once.
- Always sort before `uniq` — `uniq` only catches adjacent duplicates, not duplicates scattered throughout an unsorted file.
- Use `sort -n` whenever sorting numbers — the default lexicographic sort puts `"10"` before `"9"`, which is rarely what's intended.
- Test `sed -i` substitutions without `-i` first (or with `-i.bak`) — in-place edits are immediate and irreversible.
- Reach for `cut` when you just need a column with no conditions; reach for `awk` as soon as you need filtering, computation, or reformatting.
- Redirect stderr explicitly (`2>`, `2>&1`, `2>/dev/null`) when you need to separate genuine output from error messages, especially in scripts where mixing the two can corrupt downstream processing.
- Use `tee` instead of plain redirection when you need to both capture output to a file AND watch it live in the terminal — especially useful for long-running commands you're monitoring as they go.