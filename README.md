# Typst live preview for BBEdit

Live, as-you-type preview of Typst documents inside BBEdit's own Preview window, plus an optional "watch and open the PDF" command.

## What's included

| Piece | Installs to (`~/Library/Application Support/BBEdit/…`) | What it does |
|---|---|---|
| `Preview Filters/Typst Preview.sh` | `Preview Filters/` (plus a `DefaultFilter_Typst` link) | Compiles the current buffer, unsaved edits included, to SVG pages and shows them in **Markup › Preview in BBEdit**. |
| `Language Modules/Typst.plist` | `Language Modules/` | Makes `.typ` files the "Typst" language: syntax colouring for comments, strings and keywords, and headings in the function menu. |
| `Scripts/Typst Watch PDF.sh` | `Scripts/` | Toggles `typst watch` for the front document and opens the PDF next to it. |

## Install

```sh
brew install typst          # if you don't have it yet
git clone https://github.com/garrekstemo/typst-bbedit-preview ~/Developer/typst-bbedit-preview
bash ~/Developer/typst-bbedit-preview/install.sh
```

The installer links BBEdit to the files in the clone rather than copying them, so keep the clone where it is. To update later, `git pull` in the clone; there's no reinstall step. Restart BBEdit only when the language module changed, since BBEdit reads language modules at launch.

Restart BBEdit, open a `.typ` file and choose **Markup › Preview in BBEdit**. Put the preview window beside the editor; it refreshes as you type.

To remove everything: `bash install.sh --uninstall`.

## How it works

BBEdit pipes the document text to the preview filter on stdin and shows the HTML the filter prints. The filter runs `typst compile - page-{0p}.svg --root <document folder>`, then puts each page into the HTML as an image. Because the filter reads the buffer rather than the file, you see changes before saving.

* **Errors don't blank the preview.** When the document fails to compile mid-edit, the last good render stays on screen, dimmed, under a banner showing Typst's error message with the line number. Warnings show in a yellow banner.
* **Relative paths work.** `#include`, `#image` and `#read` resolve against the document's folder. BBEdit doesn't tell preview filters which file they're rendering, and it can't answer AppleScript while a filter runs, so a small background helper (`lib/bbedit-docwatch.sh`) asks BBEdit once a second which files are open. The filter picks the open `.typ` file whose saved text is closest to what it was given. The helper starts with the first preview and exits when BBEdit quits. The first time, macOS asks whether it may control BBEdit; allow it.
* **The document can tell it's being previewed.** `sys.inputs.at("bbedit-preview", default: "false") == "true"` is true only in the preview, if you want to hide something or render a draft mark.
* **Packages work.** `@preview/…` imports download on first use, like with the CLI.

## Which mode to use

| | Preview filter | Typst Watch PDF |
|---|---|---|
| Updates | as you type | on save |
| Output | SVG pages in BBEdit | the real PDF in Preview or Skim |
| Speed on large documents | recompiles from scratch on each refresh | incremental (`typst watch`) |
| Best for | writing and layout tweaks | final checks, long books and theses |

For a long document, if the preview starts to lag, switch to Typst Watch PDF. Set `PDF_VIEWER=Skim` in the config file and turn on Skim's file-change checking, so the PDF reloads on each save.

## Settings (optional)

Create `~/.config/typst-bbedit-preview/config`. It's a shell file, for example:

```sh
TYPST_BIN=/opt/homebrew/bin/typst      # if typst isn't on a standard path
TYPST_FONT_PATHS="$HOME/Fonts"         # extra font folders
TYPST_PREVIEW_WIDTH="100%"             # page size: 100% fits the window (default),
                                       # "700px" fixed, "150%" zoom past the window
TYPST_PREVIEW_ARGS=""                  # extra args for the preview compile
TYPST_WATCH_ARGS=""                    # extra args for typst watch
PDF_VIEWER=Skim
```

## Troubleshooting

* **The preview shows plain text or HTML-escaped source.** BBEdit didn't apply the filter. Pick **Typst Preview** from the filter menu in the preview window's navigation bar; BBEdit remembers the choice for each document. Also check that the status bar shows the language as "Typst" (the language module loads after a restart).
* **"file location not known yet".** The background helper hadn't reported yet (this happens on the very first preview after BBEdit starts), or the document has never been saved. Save the file and type a character to refresh. If it persists, check System Settings › Privacy & Security › Automation lets the helper control BBEdit. Setting `TYPST_PREVIEW_DEBUG=1` in the config file writes what the filter saw to `~/Library/Caches/typst-bbedit-preview/debug.txt`.
* **Absolute paths (`/assets/logo.png`)** resolve against the document's folder, not a project root above it, because the buffer comes in on stdin.

## Tested

The filter, installer and watch script were tested on Linux with typst 0.15.1, with BBEdit's behaviour simulated (buffer on stdin, `BB_DOC_PATH` set). They have not yet been run inside BBEdit on a Mac.
