
# Setup

Add a list of pike sources to vimrc, at least one is required:

```
let g:pikedoc_pike_sources = ['/path/to/your/sources']
```
This can be a list of paths (strings) or dictionaries, each with
`path` and `imgsrc` entries. If doc_extractor is failing because of
images, most likly you need to specify `imgsrc` for it to work properly

Note that this is prealfa stage, so more sources may not work well yet.

# Usage

With cursor over a pike method/class/module press `<C-i>` (will be customizable later)
A window above will popup, you need to close it manually currently, as plugin will
spawn new window with each call.

## Note

This is early stage of development, most planned things don't work yet, so stay tuned ;)

