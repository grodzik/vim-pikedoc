
# Setup

Add a list of pike sources to vimrc, at least one is required:

```
let g:pikedoc_pike_sources = ['/path/to/your/sources']
```

Note that this is prealfa stage, so more sources may not work well yet.

# Usage

With cursor over a pike method/class/module press `<C-i>` (will be customizable later)
A window above will popup, you need to close it manually currently, as plugin will
spawn new window with each call.

## Note

This is early stage of development, most planned things don't work yet, so stay tuned ;)
