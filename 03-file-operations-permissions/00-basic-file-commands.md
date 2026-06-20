# Basic File Commands

A quick-reference guide to the core Linux commands for navigating, creating, viewing, copying, moving, deleting, searching, permissioning, and archiving files and directories.

---

## 📁 Navigation

### `pwd` — Print Working Directory
Shows the full path of the directory you're currently in.

```bash
pwd
# /home/user/projects
```

### `cd` — Change Directory
Moves you between directories.

```bash
cd /home/user/projects   # absolute path
cd projects               # relative path
cd ..                     # move up one level
cd ~                      # go to home directory
cd -                      # go back to the previous directory
```

### `ls` — List Directory Contents
Lists files and folders in the current (or specified) directory.

```bash
ls              # basic listing
ls -l           # long format (permissions, size, date)
ls -a           # include hidden files (those starting with .)
ls -la          # combine both
ls -lh          # human-readable file sizes (e.g. 4.0K, 1.2M)
```

---

## 📄 Creating Files & Directories

### `mkdir` — Make Directory
Creates a new directory.

```bash
mkdir new-folder
mkdir -p path/to/nested/folder   # create parent dirs as needed
```

### `touch` — Create an Empty File
Not in the original list, but worth knowing alongside `mkdir`:

```bash
touch notes.txt
```

---

## 📋 Copying & Moving

### `cp` — Copy
Copies files or directories.

```bash
cp file.txt backup.txt          # copy a file
cp file.txt /path/to/dest/      # copy into a directory
cp -r folder/ backup-folder/    # copy a directory recursively
cp -i file.txt backup.txt       # prompt before overwriting
```

### `mv` — Move / Rename
Moves files or directories — and since there's no separate "rename" command in Linux, `mv` does that too.

```bash
mv file.txt /path/to/dest/      # move a file
mv old-name.txt new-name.txt    # rename a file
mv -i file.txt dest/            # prompt before overwriting
```

> **Tip:** `cp` duplicates data; `mv` relocates it. If `mv` is moving a file *within the same filesystem*, it's just relinking — that's why it's instant even for huge files.

---

## 👀 Viewing & Reading Files

### `cat` — Concatenate & Display
Prints a file's entire contents to the terminal. Also useful for quickly combining files.

```bash
cat file.txt                  # display file contents
cat file1.txt file2.txt       # display multiple files in sequence
cat file1.txt file2.txt > combined.txt   # merge files into one
cat -n file.txt                # show line numbers
```

### `less` — Page Through a File
Opens a file for scrollable, searchable viewing without loading it all into memory at once — ideal for large files.

```bash
less file.txt
# inside less:
#   space / b      → page down / up
#   /search-term   → search forward
#   q              → quit
```

### `head` — View the Start of a File
Shows the first lines of a file (10 by default).

```bash
head file.txt
head -n 20 file.txt     # first 20 lines
```

### `tail` — View the End of a File
Shows the last lines of a file (10 by default). Commonly used to monitor logs in real time.

```bash
tail file.txt
tail -n 20 file.txt     # last 20 lines
tail -f /var/log/syslog # "follow" — stream new lines as they're written
```

### `nano` — Simple Terminal Text Editor
A beginner-friendly text editor for creating or editing files directly in the terminal.

```bash
nano file.txt
# Ctrl+O → save   Ctrl+X → exit   Ctrl+W → search
```

> **Tip:** Use `cat` for short files you want to dump to the screen, `less` for anything long, and `tail -f` for watching a file change live (e.g. log monitoring).

---

## 🗑️ Removing Files & Directories

### `rm` — Remove
Deletes files (and, with flags, directories).

```bash
rm file.txt          # delete a file
rm -i file.txt        # prompt before deleting
rm -r folder/         # delete a directory and its contents
rm -rf folder/        # force delete, no prompts (⚠️ use with care)
```

### `rmdir` — Remove Directory
Deletes a directory, but **only if it's empty**.

```bash
rmdir empty-folder
```

> ⚠️ **Warning:** `rm -rf` is permanent and irreversible — there is no trash bin to recover from. Double-check your path (especially when using wildcards like `*`) before running it.

---

## 🔍 Searching & Visualizing

### `find` — Search for Files
Searches a directory tree for files matching criteria.

```bash
find . -name "*.txt"             # find all .txt files in current dir and below
find /home -type d -name "logs"  # find directories named "logs"
find . -mtime -7                 # files modified in the last 7 days
find . -size +100M               # files larger than 100MB
```

### `tree` — Visualize Directory Structure
Displays a directory's contents as a tree diagram. (May need to be installed: `sudo apt install tree`.)

```bash
tree                 # show full tree from current directory
tree -L 2            # limit depth to 2 levels
tree -d              # show only directories
```

---

## 🔐 Permissions & Ownership

### `chmod` — Change Mode (Permissions)
Controls who can read, write, or execute a file. Permissions are set for **u**ser, **g**roup, and **o**thers.

```bash
chmod 755 script.sh        # rwx for owner, r-x for group & others
chmod +x script.sh         # add execute permission for everyone
chmod -w file.txt          # remove write permission for everyone
chmod u+rwx,g+rx,o-rwx file.txt   # set permissions symbolically per group
```

| Number | Permission | Meaning |
|---|---|---|
| `7` | `rwx` | read + write + execute |
| `6` | `rw-` | read + write |
| `5` | `r-x` | read + execute |
| `4` | `r--` | read only |
| `0` | `---` | no permissions |

### `chown` — Change Owner
Changes which user (and optionally group) owns a file or directory.

```bash
chown user file.txt              # change owner
chown user:group file.txt        # change owner and group
chown -R user:group folder/      # apply recursively to a directory
```

### `chgrp` — Change Group
Changes only the group ownership of a file.

```bash
chgrp developers file.txt
chgrp -R developers folder/   # apply recursively
```

> **Tip:** Run `ls -l` to see current permissions and ownership before changing them — the output looks like `-rwxr-xr-- 1 user group`.

---

## 🗜️ Compression & Archiving

### `tar` — Tape Archive
Bundles multiple files/directories into a single archive file, optionally compressed.

```bash
tar -cvf archive.tar folder/        # create an archive (no compression)
tar -czvf archive.tar.gz folder/    # create + gzip-compress
tar -xvf archive.tar                # extract an archive
tar -xzvf archive.tar.gz            # extract a gzip-compressed archive
tar -tvf archive.tar                # list contents without extracting
```
Flags: `c` create, `x` extract, `v` verbose, `z` gzip, `f` file (must come last before the filename).

### `gzip` / `gunzip` — Compress Single Files
Compresses (or decompresses) individual files, replacing the original by default.

```bash
gzip file.txt          # creates file.txt.gz, removes original
gunzip file.txt.gz     # restores file.txt, removes .gz
gzip -k file.txt       # keep the original file too
```

### `zip` / `unzip` — Cross-Platform Archives
Creates `.zip` archives, widely compatible with Windows and macOS.

```bash
zip archive.zip file1.txt file2.txt   # zip specific files
zip -r archive.zip folder/            # zip a directory recursively
unzip archive.zip                      # extract to current directory
unzip -l archive.zip                   # list contents without extracting
```

> **Tip:** Use `tar.gz` for Linux-to-Linux transfers and backups (better compression, preserves permissions); use `.zip` when sharing with Windows/macOS users.

---

## ⚡ Quick Reference Table

| Command | Purpose | Common Flags |
|---|---|---|
| `pwd` | Show current directory | — |
| `cd` | Change directory | `~`, `-`, `..` |
| `ls` | List contents | `-l`, `-a`, `-h` |
| `mkdir` | Create directory | `-p` |
| `touch` | Create empty file | — |
| `cp` | Copy files/dirs | `-r`, `-i` |
| `mv` | Move/rename | `-i` |
| `cat` | Display full file contents | `-n` |
| `less` | Page through a file | — |
| `head` | Show start of file | `-n` |
| `tail` | Show end of file | `-n`, `-f` |
| `nano` | Edit file in terminal | — |
| `rm` | Delete files/dirs | `-r`, `-f`, `-i` |
| `rmdir` | Delete empty directory | — |
| `find` | Search for files | `-name`, `-type`, `-mtime` |
| `tree` | Visualize directory tree | `-L`, `-d` |
| `chmod` | Change permissions | `+x`, `-R`, numeric (e.g. `755`) |
| `chown` | Change owner/group | `-R` |
| `chgrp` | Change group | `-R` |
| `tar` | Archive (and compress) files | `-c`, `-x`, `-z`, `-v`, `-f` |
| `gzip` / `gunzip` | Compress/decompress single file | `-k` |
| `zip` / `unzip` | Cross-platform archive | `-r`, `-l` |

---

## 💡 Best Practices

- Use `-i` with `rm`, `cp`, and `mv` when you want a safety prompt before overwriting or deleting.
- Always `ls` a directory before running `rm -rf` on it — confirm exactly what you're about to delete.
- Use `find` instead of manually browsing when searching large directory trees.
- Combine `tree -L 2` for a quick visual overview of a project's structure without overwhelming detail.
- Prefer `less` over `cat` for large files — `cat` will flood your terminal, `less` lets you scroll and search.
- Use `tail -f` to watch logs update live instead of repeatedly re-running `cat`.
- Avoid `chmod 777` (full access for everyone) unless you genuinely need it — it's a common security misstep.
- Check ownership and permissions with `ls -l` before and after using `chown`/`chmod` to confirm the change applied as expected.
- Use `tar -czvf` for backups and Linux-to-Linux transfers; use `zip` when sharing across operating systems.
- Test an archive with `tar -tvf` or `unzip -l` before extracting, to preview contents and avoid cluttering your directory.