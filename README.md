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
