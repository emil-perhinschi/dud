# dud: A build and dependency tool for the D programming language

[![Build Status](https://travis-ci.com/symmetryinvestments/dud.svg?branch=master)](https://travis-ci.com/symmetryinvestments/dud)

Dud is meant to be a reasonable drop in replacement for
[dub](https://github.com/dlang/dub).

IMHO the dub codebase is hard to get into and high coupled.
Meaning that, if you fix one thing you might break another.

Dud's implementation tries to be boring.
Dud is to be written in a declarative and functional style.

Testing is paramount.

## Features
Most things do not work and are not even implemented yet.
Currently, the focus is on getting the data structures correct.

Given the below displayed list of dub features, dud's current feature set is
extremely limited.

### Package creation
- [ ] init

### Build, test and run
- [ ] run
- [ ] build
- [ ] test
- [ ] generate
- [ ] describe
- [ ] clean
- [ ] dustmite

### Package management
- [ ] fetch
- [ ] add
- [ ] remove
- [ ] upgrade
- [ ] add-path
- [ ] remove-path
- [ ] add-local
- [ ] remove-local
- [ ] list
- [ ] search
- [ ] add-override
- [ ] remove-override
- [ ] list-overrides
- [ ] clean-caches
- [x] convert

## Documentation
See Contributing section

## Contributing
PRs or issues are always welcome!

### Building
To build dud run:

```sh
$ dub build
```

Each subpackage should be buildable with the same shell command.

### Testing
To test the individual subpackages run:

```sh
$ dub test
```
in the subpackage folder.

To execute the excessive tests --
Excessive, in this case means, downloading all packages from code.dlang.org,
creating a folder for each tag for each package and running tests on all of
them -- run:

```sh
$ cd testdata
$ make // This requires ~ 63GB of disk space
$ cd ../sdlang
$ dub --config=ExcessiveTests
$ cd ../pkgdescription
$ dub --config=ExcessiveTests
```

It is not indented that dud can ingest all dub.(sdl|json) found, instead the
idea is to have a large, real world test set.

# About Kaleidic Associates
We are a boutique consultancy that advises a small number of hedge fund clients.
We are not accepting new clients currently, but if you are interested in working
either remotely or locally in London or Hong Kong, and if you are a talented
hacker with a moral compass who aspires to excellence then feel free to drop me
a line: laeeth at kaleidic.io

We work with our partner Symmetry Investments, and some background on the firm
can be found here:

http://symmetryinvestments.com/about-us/
