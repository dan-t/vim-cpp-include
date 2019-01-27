vim-cpp-include
===============

This is a plugin for the [vim](http://www.vim.org/) editor for extending the include
list of a C/C++ source file with the aid of a [tags](https://en.wikipedia.org/wiki/Ctags) file.

Installation
============

The recommended way is to use any plugin manager, like [pathogen.vim](<https://github.com/tpope/vim-pathogen/>):

    $> cd ~/.vim/bundle
    $> git clone https://github.com/dan-t/vim-fn
    $> git clone https://github.com/dan-t/vim-cpp-include

Quick Start
===========

The main information for the plugin are the locations of the C/C++ header files
which are defined by `g:cpp_include_origins`:

    let g:cpp_include_origins = [
       \ ['std', { 'version': 'c++11', 'surround': '<', 'sort_order': 0 }],
       \ ['my_app', { 'directory': '/path_to_headers_of_my_app/', 'surround': '"', 'sort_order': 1 }],
       \ ['some_lib', { 'directory': '/path_to_headers_of_some_lib/', 'surround': '"', 'sort_order': 2 }]]
 
This defines three origins: `std`, `my_app` and `some_lib`. The `surround` defines how the includes from
the origin are formated. So the `<` for `std` yields an include like: `#include <vector>`. The `sort_order`
defines how the includes are sorted. The currently supported versions of `std` are: `c++11`, `c++14` and `c++17`.

Now calling `:CppInclude vector` should add the include `#include <vector>`. If there were no includes present
before, then you have to choose an include position. For the automatic choosing of the position of the first include
take a look at `g:cpp_include_position_fallback`.

Calling `:CppInclude` without any argument will take the name under the cursor, so you can use it to define a mapping.

The present includes can be sorted by calling `:CppIncludeSort`, which uses `sort_order` for the sorting.

Configuration
=============

g:cpp_include_header_extensions
-------------------------------
(default=["h", "", "hh", "hpp", "hxx"])

Only tags from header files are considered. The lowercase extension of the tag filename is
compared with `g:cpp_include_header_extensions`.

g:cpp_include_kinds_order
-------------------------
(default=[["c", "s", "g", "u", "t", "d"], ["p", "f", "x"]])

Only tags of certain kinds are considered. For the meaning of the kinds take a look at
the output of `ctags --list-kinds=C++`. Each list or string inside of `cpp_include_kinds_order`
is considered as one group. The groups act as a filter on the tags. E.g. if for the name
`vector` there is a class definition (kind="c") and a function definition (kind="f"), then
the class definition is prefered, because "c" is in front of "f".

g:cpp_include_forced_headers
----------------------------
(default={})

If the same name has multiple tags, which means you've to choose which tag should be used, but
for this name you always want to use the same tag and therefore header, then you can force
the used header by:

    let g:cpp_include_forced_headers = { 
       \ 'some_name': { 'origin': 'my_app', 'path': 'SomeHeader.h' } }

g:cpp_include_default_surround
------------------------------
(default='"')

If there's no `surround` entry for the origin then `g:cpp_include_default_surround` is used.

g:cpp_include_position_fallback
-------------------------------
(default=[])

If there're no includes present, then an include position has to be choosen. With
`g:cpp_include_position_fallback` it's possible to automatically choose the first position:

    let g:cpp_include_position_fallback = [
       \ { 'line_regex': '^// includes', 'pos': 'below' },
       \ { 'line': 1, 'pos': 'above' } ]

This would first search for a line matching `^// includes`, and if one could be found, the
include would be placed below it. Otherwise the include would be placed above the first line.
