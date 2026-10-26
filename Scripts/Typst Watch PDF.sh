#!/bin/bash
#
# Typst Watch PDF: a BBEdit script (Scripts menu).
#
# Toggles `typst watch` for the front document. The first run starts a
# background watcher that rebuilds <name>.pdf next to the source on every
# save and opens the PDF; running it again on the same document stops the
# watcher. Use this when you want exact PDF output, or for large documents
# where the as-you-type preview filter is too slow.
#
# Set PDF_VIEWER in ~/.config/typst-bbedit-preview/config to pick the app
# (Skim reloads changed PDFs automatically; set its "Check for file
# changes" preference).

CONFIG="$HOME/.config/typst-bbedit-preview/config"
[ -f "$CONFIG" ] && . "$CONFIG"

PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/.cargo/bin:$HOME/.local/bin:/opt/local/bin"
TYPST_BIN="${TYPST_BIN:-$(command -v typst)}"

notify() {
    osascript -e "display notification \"$1\" with title \"Typst Watch\"" >/dev/null 2>&1
}

src="$BB_DOC_PATH"
case "$src" in
    *.typ) ;;
    *) notify "Save the document as a .typ file first."; exit 1 ;;
esac
if [ -z "$TYPST_BIN" ]; then
    notify "typst not found. Install it with: brew install typst"
    exit 1
fi

state_dir="$HOME/Library/Caches/typst-bbedit-preview/watch"
mkdir -p "$state_dir"
key=$(printf '%s' "$src" | cksum | cut -d' ' -f1)
pid_file="$state_dir/$key.pid"
log_file="$state_dir/$key.log"
pdf="${src%.typ}.pdf"

if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    kill "$(cat "$pid_file")"
    rm -f "$pid_file"
    notify "Stopped watching $(basename "$src")"
    exit 0
fi

cd "$(dirname "$src")" || exit 1
# shellcheck disable=SC2086
nohup "$TYPST_BIN" watch $TYPST_WATCH_ARGS "$src" "$pdf" > "$log_file" 2>&1 &
echo $! > "$pid_file"
notify "Watching $(basename "$src")"

# Wait briefly for the first build before opening the viewer.
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    [ -f "$pdf" ] && break
    sleep 0.25
done
if [ -n "$PDF_VIEWER" ]; then
    open -g -a "$PDF_VIEWER" "$pdf"
else
    open -g "$pdf"
fi
