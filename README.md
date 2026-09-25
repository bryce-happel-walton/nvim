# nvim

Neovim set up to feel like VS Code, with Rust support.

## Install

Requirements:

- Neovim 0.12+
- `git`, `rg` (ripgrep), `curl`
- A [Nerd Font](https://www.nerdfonts.com/) in your terminal
- Rust tools: `rustup component add rust-analyzer rustfmt`
- A terminal with the kitty keyboard protocol (kitty, WezTerm, Ghostty, foot, Alacritty, iTerm2 with "CSI u" on).
  Without it, shortcuts using Shift, Tab or digits (like `Ctrl+Shift+O`) can't be told apart.

```sh
git clone https://github.com/bryce-happel-walton/nvim ~/.config/nvim
nvim   # plugins install on first start
```

**macOS:** each `Ctrl` shortcut is also mapped to `Cmd`. This works in Neovide, and in terminals
that pass Cmd through to apps (kitty, WezTerm, Ghostty).

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
 branch │ 󰓦 incoming↓ outgoing↑ │ blame of current line │ errors warnings │ TODOs │ Ln, Col (selected) │ language
```

- **Sync:** click to pull and then push, or "Publish" to push a new branch. Fetches every 3 minutes, like VS Code's autofetch.
- **Errors/warnings:** counts for the whole workspace; click for the Problems list.
- **TODOs:** `TODO`, `FIXME`, `HACK`, `XXX` and `BUG` comments across the workspace (skips `.gitignore`d files); click to list them.
- The Vim mode is shown below the status bar.

## Layout

```
init.lua
lua/config/   options, keymaps, status bar, helpers
lua/plugins/  ui (theme, tabs, status bar), snacks (pickers, explorer, terminal),
              editor (multi-cursor), lsp (completion, rust-analyzer, format), git
```
