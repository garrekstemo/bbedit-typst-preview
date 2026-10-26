#!/bin/bash
#
# Typst Preview: a BBEdit preview filter.
#
# BBEdit pipes the current (possibly unsaved) document text to stdin and
# shows whatever HTML this script writes to stdout in its Preview window,
# refreshing as you type. We compile the text with `typst` to one SVG per
# page and wrap the pages in a small HTML page.
#
# When the document has an error mid-edit, the last good render is kept
# on screen under an error banner, so the preview doesn't blank out while
# you type.
#
# Optional settings live in ~/.config/typst-bbedit-preview/config, which
# is sourced as a shell file. Recognised variables:
#   TYPST_BIN           path to the typst binary
#   TYPST_PREVIEW_ARGS  extra arguments for `typst compile` (word-split)
#   TYPST_FONT_PATHS    extra font directories (read by typst itself)
#   TYPST_PREVIEW_DEBUG set to 1 to write the filter's environment to
#                       ~/Library/Caches/typst-bbedit-preview/debug.txt
#   TYPST_PREVIEW_WIDTH page width as CSS: "100%" fits the window (default),
#                       "700px" is a fixed size, "150%" zooms past the window

CONFIG="$HOME/.config/typst-bbedit-preview/config"
[ -f "$CONFIG" ] && . "$CONFIG"

# BBEdit's filter environment can have a short PATH, so also look in the
# usual install locations.
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/.cargo/bin:$HOME/.local/bin:/opt/local/bin"
TYPST_BIN="${TYPST_BIN:-$(command -v typst)}"

work=$(mktemp -d "${TMPDIR:-/tmp}/typst-preview.XXXXXX") || exit 1
trap 'rm -rf "$work"' EXIT

cat > "$work/input.typ"

cache_dir="${XDG_CACHE_HOME:-$HOME/Library/Caches}/typst-bbedit-preview"
mkdir -p "$cache_dir"

# Relative paths (#include, #image, #read) resolve against --root when the
# source comes from stdin, so the root must be the document's own folder.
# BBEdit doesn't tell preview filters which file they're rendering, and it
# can't answer AppleScript while a filter runs. So a background helper
# (lib/bbedit-docwatch.sh) keeps a list of BBEdit's open files, and we pick
# the .typ file whose saved text is closest to the text we were given.
self="$0"
while [ -L "$self" ]; do
    link=$(readlink "$self")
    case "$link" in
        /*) self="$link" ;;
        *) self="$(dirname "$self")/$link" ;;
    esac
done
docwatch="$(cd "$(dirname "$self")/.." && pwd)/lib/bbedit-docwatch.sh"
open_docs="$cache_dir/open-documents.txt"
docwatch_pid="$cache_dir/docwatch.pid"
if [ -x "$docwatch" ] && command -v osascript >/dev/null &&
   ! { [ -f "$docwatch_pid" ] && kill -0 "$(cat "$docwatch_pid")" 2>/dev/null; }; then
    nohup "$docwatch" "$open_docs" "$docwatch_pid" </dev/null >/dev/null 2>&1 &
fi

doc_path="${BB_DOC_PATH:-}"
if [ -z "$doc_path" ] && [ -f "$open_docs" ]; then
    best_diff=""
    while IFS= read -r candidate; do
        case "$candidate" in *.typ) ;; *) continue ;; esac
        [ -f "$candidate" ] || continue
        if cmp -s "$work/input.typ" "$candidate"; then
            doc_path="$candidate"
            break
        fi
        # Skip files that share less than half their lines with the text,
        # so an unsaved new document doesn't borrow another file's folder.
        changed=$(diff "$work/input.typ" "$candidate" | grep -c '^[<>]')
        total=$(cat "$work/input.typ" "$candidate" | wc -l)
        [ $((changed * 2)) -le "$total" ] || continue
        if [ -z "$best_diff" ] || [ "$changed" -lt "$best_diff" ]; then
            best_diff="$changed"
            doc_path="$candidate"
        fi
    done < "$open_docs"
fi
if [ -n "$doc_path" ] && [ -d "$(dirname "$doc_path")" ]; then
    doc_dir=$(dirname "$doc_path")
    doc_name=$(basename "$doc_path")
else
    doc_path=""
    doc_dir="$PWD"
    doc_name="untitled.typ"
fi

if [ -n "$TYPST_PREVIEW_DEBUG" ]; then
    { date; echo "args=$*"; echo "doc_path=$doc_path"; echo "PWD=$PWD"; env; } > "$cache_dir/debug.txt"
fi
# The last good render is kept per document; an unsaved document has no
# stable key, so it gets none rather than showing another file's pages.
last_good=""
if [ -n "$doc_path" ]; then
    cache_key=$(printf '%s' "$doc_path" | cksum | cut -d' ' -f1)
    last_good="$cache_dir/$cache_key.html"
fi

escape_html() {
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

page_header() {
    cat <<'EOF'
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  :root { color-scheme: light dark; --bg: #e8e8ea; --fg: #222; --shadow: rgba(0,0,0,.25);
          --err-bg: #fdecea; --err-fg: #8a1c12; --err-border: #e0a39c;
          --warn-bg: #fff6dd; --warn-fg: #6b4e00; --warn-border: #e6cf8a; }
  @media (prefers-color-scheme: dark) {
    :root { --bg: #2a2a2e; --fg: #ddd; --shadow: rgba(0,0,0,.6);
            --err-bg: #3d1f1c; --err-fg: #ffb4a9; --err-border: #7a3a32;
            --warn-bg: #3a3220; --warn-fg: #f3d58a; --warn-border: #6e5d2e; }
  }
  html, body { margin: 0; background: var(--bg); color: var(--fg);
               font: 13px -apple-system, system-ui, sans-serif; }
  main { padding: 12px; }
  .page { display: block; height: auto; margin: 0 auto 12px; background: #fff;
          box-shadow: 0 1px 4px var(--shadow); }
  .banner { position: sticky; top: 0; z-index: 1; margin: 0; padding: 8px 12px;
            border-bottom: 1px solid; max-height: 40vh; overflow: auto; }
  .banner pre { margin: 4px 0 0; font: 12px ui-monospace, Menlo, monospace; white-space: pre-wrap; }
  .error { background: var(--err-bg); color: var(--err-fg); border-color: var(--err-border); }
  .warning { background: var(--warn-bg); color: var(--warn-fg); border-color: var(--warn-border); }
  .stale main { opacity: .55; }
  .empty { padding: 48px 16px; text-align: center; opacity: .6; }
</style>
EOF
    printf '<style>.page { width: %s; }</style>\n</head>\n' "${TYPST_PREVIEW_WIDTH:-100%}"
}

banner() {  # banner <class> <title> <file with diagnostics>
    printf '<div class="banner %s"><strong>%s</strong><pre>' "$1" "$2"
    name=$(printf '%s' "$doc_name" | sed 's/[#&\\]/\\&/g')
    sed -e "s#<stdin>#$name#g" "$3" | escape_html
    printf '</pre></div>\n'
}

if [ -z "$TYPST_BIN" ] || [ ! -x "$TYPST_BIN" ]; then
    page_header
    printf '<body><div class="banner error"><strong>typst not found</strong><pre>'
    printf 'Install it with "brew install typst", or set TYPST_BIN in\n%s' "$CONFIG" | escape_html
    printf '</pre></div></body></html>\n'
    exit 0
fi

# shellcheck disable=SC2086
"$TYPST_BIN" compile \
    --root "$doc_dir" \
    --input bbedit-preview=true \
    --diagnostic-format human \
    $TYPST_PREVIEW_ARGS \
    - "$work/page-{0p}.svg" < "$work/input.typ" 2> "$work/stderr"
status=$?

if [ $status -eq 0 ]; then
    {
        printf '<main>\n'
        found=0
        for svg in "$work"/page-*.svg; do
            [ -f "$svg" ] || continue
            found=1
            # Pages go in as data-URI images rather than inline <svg> so that
            # element ids in one page's SVG can't collide with another's.
            printf '<img class="page" alt="" src="data:image/svg+xml;base64,'
            base64 < "$svg" | tr -d '\n'
            printf '">\n'
        done
        [ $found -eq 0 ] && printf '<div class="empty">This document has no pages.</div>\n'
        printf '</main>\n'
    } > "$work/body.html"
    [ -n "$last_good" ] && cp "$work/body.html" "$last_good"

    page_header
    printf '<body>\n'
    [ -s "$work/stderr" ] && banner warning "Warnings" "$work/stderr"
    cat "$work/body.html"
    printf '</body></html>\n'
else
    page_header
    if [ -n "$last_good" ] && [ -f "$last_good" ]; then
        printf '<body class="stale">\n'
        banner error "Compile error (showing last good render)" "$work/stderr"
        cat "$last_good"
    else
        printf '<body>\n'
        if [ -z "$doc_path" ]; then
            banner error "Compile error (file location not known yet: save the file, then type to refresh)" "$work/stderr"
        else
            banner error "Compile error" "$work/stderr"
        fi
    fi
    printf '</body></html>\n'
fi
