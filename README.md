# What's this

Pike's source code documentation viewer. It generates documentation from source code
to text files and displays proper one in Vim's preview window.

## Requirements

 - [Pike](http://pike.lysator.liu.se) in version 8.0 or greater
 - Pike's sources to get documentation for core/builtin methods

## Installation

Use your preffered Vim plugin manager, like
[Pathogen](https://github.com/tpope/vim-pathogen),
[Vundle](https://github.com/VundleVim/Vundle.vim),
[Dein](https://github.com/Shougo/dein.vim) or any other that works for you.

Or just drop `ftplugin/pike.vim` and `tools/doc_extractor.pike` to your `$HOME/.vim/` direcotry.

Last and most important step is to add a list of pike sources to vimrc, at least one path is required:

```VimL
let g:pikedoc_pike_sources = ['/path/to/your/sources']
```
For description of this variable as well as others go to [Options](https://github.com/grodzik/vim-pikedoc/blob/master/README.md#options).

## Usage

With cursor over a pike method/class/module press `<C-i>` (will be customizable later)
A window above will popup, you need to close it manually currently, as plugin will
spawn new window with each call.

## Mappings

### Local key mappings
| Combination | Description |
| --- | --- |
| `q` | close preview window |
| `p` | display description of parent module/class/namespace |
| `m` | show list of methods for current module/class/namespace |
| `M` | show list of modules for current module/class/namespace |
| `c` | show list of classes for current module/class/namespace |

### Global key mappings

If you set
```VimL
let g:pikedoc_define_mappings = 1
```
in your `$HOME/.vimrc`, there will be some key mappings added for easy use. This can be further customized with
```VimL
let g:pikedoc_master_key = 'p'
```
`p` is the default setting for what's visible in the table below as `<MasterKey>`

| Combination | Command | Description |
| --- | --- | --- |
| `<Leader><MasterKey>p` | call PikeDoc | show help for word under the cursor if available |
| `<Leader><MasterKey>g` | call PikeDocGenerate | (re)generate documentation cache |


## Options

### Mandatory

 - **g:pikedoc_pike_sources** - A list of paths for source to generate documentation from.
If documentation uses images inside it (a.k.a Mirar doc style) it is required to
provide also a path for image sources. In such case entry that requires images should be a dictionary
with `path` and `imgsrc` keys. Note that if you prefer all entries can be dictionaries,
`imsrc` is optional key in each dictionary.
```VimL
let g:pikedoc_pike_sources = ['/path/to/your/sources']

" or

let g:pikedoc_pike_sources = [ {'path':'/path/to/your/sources/', 'imgsrc':'/path/to/img/sources'} ]
```

### Optional

*Values visible in code quotes are default ones*

 - **g:pikedoc_pike_cmd** - Pike command available in `$PATH` or path to Pike's
binary that should be used to generate documentation. Pike needs to be in
version `>= 8.0`, but in can still parse code for older versions of Pike.
```VimL
let g:pikedoc_pike_cmd = 'pike'
```

 - **g:pikedoc_define_mappings** - Add mappings for faster access to PikeDoc's commands.
 List of mappings is available [here](https://github.com/grodzik/vim-pikedoc/blob/master/README.md#global_key_mappings)
```VimL
let g:pikedoc_define_mappings = 0
```

 - **g:pikedoc_master_key** - Define own prefix key for mappings
```VimL
let g:pikedoc_master_key = 'p'
```

 - **g:pikedoc_confirm_remove** - Should PikeDoc ask before removing auto
generated `pikedoc` folder in plugin directory. If this is set to `1`, you will
be ask before removal and need to type yes to actually remove `pikedoc` folder.
Regenerating documentation with not removed old one will cause it to append new
entries to old ones, instead of overwriting it (may change in future)
```VimL
let g:pikedoc_confirm_remove = 1
```
## Note

This is early stage of development, most planned things don't work yet, so stay tuned ;)

### Known issues

| What | Fix/workaround |
| --- | --- |
| Missing `lena.gif` file while generating documentation for pure Pike's sources |  add/copy any image to `refdoc/src_images` with name `lena.gif`.  Vim is text based, so it won't display images anyway, so it doesn't matter what's there |
