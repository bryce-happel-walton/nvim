# nvim

Neovim set up to feel like VS Code, with Rust support.

## Install

You need Neovim 0.12+ and Rust installed with [rustup](https://rustup.rs) (the installer from rust-lang.org). Then run:

```sh
curl -fsSL https://raw.githubusercontent.com/bryce-happel-walton/nvim/main/install.sh | sh
```

Or from a clone: `./install.sh`. It's safe to run again any time to repair or update.

It installs everything else: the config (an existing one is backed up first), the `nv`
command, rust-analyzer, rustfmt, ripgrep, the tree-sitter CLI, Hack Nerd Font, the plugins and
the syntax parsers. When it's done, set your terminal's font to **Hack Nerd Font**.

Use a terminal with the kitty keyboard protocol: kitty, WezTerm, Ghostty, foot, Alacritty, or iTerm2
with "Report keys using CSI u" turned on. Other terminals can't tell apart shortcuts with Shift,
Tab or digits, like `Ctrl+Shift+O`.

**macOS:** each `Ctrl` shortcut is also mapped to `Cmd`. This works in Neovide, and in terminals
that pass Cmd through to apps (kitty, WezTerm, Ghostty). For the `Alt` shortcuts, make the Option
key act as Alt:

| Terminal | Setting |
| --- | --- |
| Ghostty | `macos-option-as-alt = true` |
| kitty | `macos_option_as_alt yes` |
| WezTerm | `send_composed_key_when_left_alt_is_pressed = false` |
| iTerm2 | Settings > Profiles > Keys > Left Option key: Esc+ |

## Remote SSH and sessions that keep running

Start Neovim with `nv` instead of `nvim`:

```sh
nv                      # this folder, on this machine
nv ~/code/app           # another folder
nv devbox               # an SSH host (from ~/.ssh/config, or user@host): your home folder there
nv devbox:~/code/app    # a folder on an SSH host
nv --list               # sessions you've opened
```

Like VS Code Remote-SSH, the editor runs on the host (files, terminals, rust-analyzer, git) and
your terminal shows it, with all the same shortcuts.

- **Sessions keep running.** Close the terminal, lose the connection or restart your computer, and
  the session carries on with its open files and running terminals. Run the same `nv` command to
  get back to it. After a dropped connection, `nv` reconnects by itself.
- **They end when you quit** Neovim (`:qa`) or the machine they run on restarts. `:detach` leaves one
  running and returns to your shell.
- **Switch hosts and folders** from inside Neovim with `:Remote`, or by clicking **SSH: host** in the
  status bar. The session you leave keeps running.
- **Copying on a host goes to your local clipboard** (`"+y`), if your terminal supports OSC 52
  (kitty, WezTerm, Ghostty, Alacritty, foot; in iTerm2 allow clipboard access in its settings).
  Paste with your terminal's paste shortcut.

The first time you connect to a host, `nv` installs the same Neovim version and this config
there, which takes about a minute. It uses its own folders (`~/.config/nv`, `~/.local/share/nv`),
so it doesn't touch anything already on the host, and it doesn't need sudo. The host needs
`git`, `curl` and `tar`; a C compiler for the best syntax highlighting; and Rust (rustup) for
rust-analyzer. Linux hosts need glibc 2.34 or newer (Ubuntu 22.04+, Debian 12+, RHEL 9+).

If sessions on a Linux host stop when you disconnect, the host ends processes at logout; run
`loginctl enable-linger` there once.

## Keybindings

`Ctrl` means `Cmd` on macOS too.

### Files and symbols

| Key | Action |
| --- | --- |
| `Ctrl+P` | Go to file in the workspace |
| `Ctrl+Shift+O` | Go to symbol in the current file |
| `Ctrl+T` | Go to symbol in the workspace |
| `Ctrl+Shift+P` | Command palette |
| `Ctrl+Shift+F` | Search in files |
| `Ctrl+E` | Toggle explorer |
| `Ctrl+J` / ``Ctrl+` `` | Toggle terminal panel |
| `Ctrl+S` | Save |
| `Ctrl+Z` / `Ctrl+Shift+Z` / `Ctrl+Y` | Undo / redo / redo |

### Multi-cursor

| Key | Action |
| --- | --- |
| `Ctrl+D` | Select word, then add next occurrence |
| `Ctrl+K Ctrl+D` | Skip to next occurrence |
| `Ctrl+Shift+L` | Select all occurrences |
| `Ctrl+Alt+Up/Down` (or `Shift+Alt`, `Cmd+Alt`) | Add cursor above / below |
| `Alt+Click` | Add / remove cursor |
| `Esc` | Leave the selection; press again to go back to one cursor |

Selections are in Select mode, so typing replaces them just like VS Code.

### Tabs and splits

| Key | Action |
| --- | --- |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Next / previous tab |
| `Ctrl+PageDown` / `Ctrl+PageUp` | Next / previous tab |
| `Cmd+Shift+]` / `Cmd+Shift+[` | Next / previous tab (macOS) |
| `Alt+1` … `Alt+9`, `Alt+0` | Go to tab N / last tab |
| `Ctrl+Shift+PageDown/PageUp` | Move tab right / left |
| `Ctrl+W` | Close the split (if there are several), otherwise close the tab |
| `Ctrl+\` | Split editor right |
| `Ctrl+K Ctrl+\` | Split editor down |
| `Ctrl+1` … `Ctrl+9` | Focus split N (creates one if needed) |
| `Ctrl+K Ctrl+Arrow` | Focus split in that direction |

`Ctrl+W` replaces Vim's window prefix; use `:wincmd` if you need the old commands.

### Code (rust-analyzer)

| Key | Action |
| --- | --- |
| `Ctrl+.` | Hover info |
| `F12` / `Ctrl+Click` | Go to definition |
| `Ctrl+F12` | Go to implementation |
| `Shift+F12` | Find references |
| `F2` | Rename symbol |
| `Space c a` | Code action / quick fix |
| `F8` / `Shift+F8` | Next / previous problem |
| `Ctrl+Shift+M` | Problems list |
| `Shift+Alt+F` | Format document (also runs on save) |
| `Ctrl+Space` | Trigger completion (`Enter` or `Tab` accepts) |

### Git

| Key | Action |
| --- | --- |
| `Ctrl+Shift+G` | Source control: changed files, side-by-side diffs, stage (`-`), discard (`X`) |
| `Space g l` | Git graph (`Enter` on a commit shows its diff; select a range in Visual mode) |
| `Space g g` | Git menu: commit, push, pull, branches, stash |
| `Space g c` | Commit |
| `Space g h` / `Space g H` | File history / repository history |
| `]c` / `[c`, `Alt+F5` / `Shift+Alt+F5` | Next / previous change |
| `Space g p` | Peek change inline |
| `Space g s` / `Space g r` | Stage / revert change |
| `Space g b` / `Space g B` | Blame line / blame file |

In the source control view, `q` closes it and `g?` lists its keys. In the git graph, `q` closes it.

## Status bar

```
 (SSH: host) │ branch │ 󰓦 incoming↓ outgoing↑ │ blame of current line │ errors warnings │ TODOs │ Ln, Col (selected) │ language
```

- **SSH: host** shows when the session runs on an SSH host; click it to switch (`:Remote`).

- **Sync:** click to pull and then push, or "Publish" to push a new branch. Fetches every 3 minutes, like VS Code's autofetch.
- **Errors/warnings:** counts for the whole workspace; click for the Problems list.
- **TODOs:** `TODO`, `FIXME`, `HACK`, `XXX` and `BUG` comments across the workspace (skips `.gitignore`d files); click to list them.
- The Vim mode is shown below the status bar.

## Layout

```
install.sh    one-step installer
bin/nv        the nv command (lua/nv/: sessions, SSH connections, host setup)
init.lua
lua/config/   options, keymaps, status bar, tree-sitter, remote, installer steps, helpers
lua/plugins/  ui (theme, tabs, status bar), snacks (pickers, explorer, terminal),
              editor (multi-cursor), lsp (tree-sitter, completion, rust-analyzer, format), git
```
