#!/bin/bash
#
# Links the Typst preview filter, language module and watch script into
# BBEdit's Application Support folder. The links point back at this folder,
# so keep it somewhere permanent (e.g. a git clone): a `git pull` then
# updates BBEdit with no reinstall. Pass --uninstall to remove the links.

set -e
here=$(cd "$(dirname "$0")" && pwd)
support="$HOME/Library/Application Support/BBEdit"

filter="$support/Preview Filters/Typst Preview.sh"
default_filter="$support/Preview Filters/DefaultFilter_Typst"
module="$support/Language Modules/Typst.plist"
script="$support/Scripts/Typst Watch PDF.sh"

if [ "$1" = "--uninstall" ]; then
    rm -f "$filter" "$default_filter" "$module" "$script"
    echo "Removed. Restart BBEdit to unload the Typst language module."
    exit 0
fi

mkdir -p "$support/Preview Filters" "$support/Language Modules" "$support/Scripts"
chmod +x "$here/Preview Filters/Typst Preview.sh" "$here/Scripts/Typst Watch PDF.sh"
ln -sfn "$here/Preview Filters/Typst Preview.sh" "$filter"
ln -sfn "$here/Language Modules/Typst.plist" "$module"
ln -sfn "$here/Scripts/Typst Watch PDF.sh" "$script"
# BBEdit applies "DefaultFilter_<language>" automatically to documents in
# that language, so Typst files get the preview without picking a filter.
ln -sf "Typst Preview.sh" "$default_filter"

echo "Linked into $support from $here"
if ! PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/.cargo/bin" command -v typst >/dev/null; then
    echo "Note: typst isn't installed yet. Run: brew install typst"
fi
echo "Restart BBEdit, open a .typ file and choose Markup > Preview in BBEdit."
