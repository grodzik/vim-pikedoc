
# Setup

Add a list of pike sources to vimrc, at least one is required:

```
let g:pikedoc_pike_sources = ['/path/to/your/sources']
```
This can be a list of paths (strings) or dictionaries, each with
`path` and `imgsrc` entries.
```
let g:pikedoc_pike_sources = [ {'path':'/path/to/your/sources/', 'imgsrc':'/path/to/img/sources'} ]
```
For Pike source from package/git `imgsrc` should be set to `</path/to/extracted/package>/refdoc/src_images`.
If doc_extractor is failing because of images, most likly you need to
 specify `imgsrc` for it to work properly.

Note that this is prealfa stage, so more sources may not work well yet.


You can also set `g:pikedoc_pike_cmd` if you want to use pike other than
the one available in your `$PATH`. Keep in mind that this needs to be ``Pike >= 8.0``

# Usage

With cursor over a pike method/class/module press `<C-i>` (will be customizable later)
A window above will popup, you need to close it manually currently, as plugin will
spawn new window with each call.

## Mappings

When inside PikeDoc window, following mappings are available:
```
p - display description of parent module/class/namespace
m - display methods available in parent object
M - display modules available in parent object
c - display classes available in parent object
```

`<C-i>` mapping works inside those lists as well

## Note

This is early stage of development, most planned things don't work yet, so stay tuned ;)

