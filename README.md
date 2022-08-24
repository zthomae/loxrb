# lox.rb

A pair of Lox interpreters based on the materials in the book [Crafting Interpreters](https://craftinginterpreters.com/) written in Ruby.

## What Is It?

This project contains an implementation of both the tree-walking interpreter based on [part II of the book](https://craftinginterpreters.com/a-tree-walk-interpreter.html) as well as a bytecode interpreter based on [part III](https://craftinginterpreters.com/a-bytecode-virtual-machine.html).
Both interpreters rely on a shared recursive-descent parser.
The bytecode virtual machine is written in C as a shared library and run from Ruby using the [Ruby-FFI gem](https://github.com/ffi/ffi).

This project also contains a translation of the original Dart test runner into Ruby.
Most test cases have been brought over unchanged, but there are some implementation-defined differences (particularly in how errors are reported).

## Getting Started

The [`bin/setup` script](bin/setup) will download all project dependencies and build the bytecode virtual machine.

## Usage

The main project executables that you will use are stored in the [`exe/` directory](exe/). These are:

- [`lox-treewalker`](exe/lox-treewalker), for running the tree-walking interpreter.
- [`lox-bytecode`](exe/lox-bytecode), for running the bytecode interpreter.
  **Note that this only officially works on Linux and macOS**.
- [`lox-test`](exe/lox-test), for running integration tests against an interpreter.

`lox-test` will run the bundled interpreters by default, but you can override this to use another.
I've maintained the `jlox`/`clox` naming conventions for these test suites to make the parity between the book's material and my own clearer.
However, you may notice that I've removed the descriptive suffixes from the chapter names in the suites -- changing `chap18_types` to `chap18`, for example.
This is intended to make it easier to run the test suite from a specific chapter using only the chapter's number.
It's a small thing, but I found it very useful as I was working through the book.

Similarly to the original Lox interpreters, `lox-treewalker` and `lox-bytecode` can either be run on a specific source file or in REPL mode if no file is provided.

Unlike the original `clox` interpreter, `lox-bytecode` uses environment variables to control whether debugging features are turned on, rather than compiler `#define`s.
Setting one or more of these environment variables to a string other than `0` or `false` (in any capitalization) will turn their respective settings on.
These environment variables are:

- `LOXRB_LOG_DISASSEMBLY`, which will enable the printing of program disassembly as well as stack contents after every instruction.
- `LOXRB_LOG_GC`, which will emit log messages for all garbage collector related operations.
- `LOXRB_STRESS_GC`, which will cause the garbage collector to run after every reallocation that increases the program's memory footprint.
  This setting is independent of `LOXRB_LOG_GC`.
- `LOXRB_DEBUG_MODE`, which will enable all of these features.

Unlike `clox`, all diagnostic messages are prefixed so they can be distinguished from the program's primary output.
This makes it possible to run integration tests on an interpreter with debugging settings enabled.

### Building The Bytecode Virtual Machine

The [`bin/compile-native` script](bin/compile-native) will recompile the code for the bytecode virtual machine into a shared library suitable for the current platform.
As stated earlier, this is currently only intended to be used on Linux and macOS.
Other platforms are simply not expected.

### Usage Examples

```bash
# To run the tree-walking interpreter against a source file
exe/lox-treewalker cases/function/print.lox

# To run a REPL for the the bytecode interpreter
exe/lox-bytecode

# To run the bytecode interpreter in full debug mode
LOXRB_DEBUG_MODE=1 exe/lox-bytecode

# To run the bytecode interpreter with instruction disassembly turned on
LOXRB_LOG_DISASSEMBLY=1 exe/lox-bytecode

# To run the bytecode interpreter with garbage collection logged and stressed on a benchmark file
LOXRB_LOG_GC=1 LOXRB_STRESS_GC=1 exe/lox-bytecode cases/benchmark/zoo.lox

# To run the main jlox test suite against the tree-walking interpreter
exe/lox-test jlox

# To run the main clox test suite against the bytecode interpreter
exe/lox-test clox

# To run the tests for a specific chapter against a specific interpreter
exe/lox-test -i exe/lox-bytecode chap30
```

### Development Scripts

There are a few scripts in the `bin/` directory that may be useful to those working on the project.
These scripts are largely self-explanatory and take no arguments.

```bash
# To set up the project as if from scratch, redownloading dependencies and recompiling the native bytecode virtual machine extension
bin/setup

# To recompile the bytecode virtual machine only
bin/compile-native

# To start an IRB session with the Lox module included
bin/console
```

### Linting

The Ruby code in this project are formatted with [Standard](https://github.com/testdouble/standard).
You can run it with the standard Rake commands: `rake standard` to report all errors, and `rake standard:fix` to attempt to fix them.

## Project Layout

The [`lib/` directory](lib/) houses all of the Ruby modules that make up this project.
The top-level `Lox` module is broken up into the following components:

- A `Parser` module with functionality for parsing Lox source code into an abstract syntax tree.
- A `TreeWalker` module containing the tree-walking interpreter.
- A `Bytecode` module containing the driver code for the bytecode interpreter as well as supplemental features like a disassembler.
- A `Test` module exposing the integration test suite shared by both interpreters.

The bytecode virtual machine is defined in the [`ext/` directory](ext/).
This includes an [`extconf.rb` file](ext/extconf.rb) that will build the `Makefile` that in turn will build the shared library.

Scripts that may be useful during development are in the [`bin/` directory](bin/).
This directory is separated from [`exe/`](exe/) so as to reinforce the difference between executables that are intended for _working_ on the project (which go into `bin/`) from those that are used for _running_ the project (which go into `exe/`).

The [`cases/` directory](cases/) contains the integration tests that each compiler is run on.
As stated earlier, virtually all of these are copied directly from the original test suite.

There are a few perfunctory unit tests in the [`spec/` directory](spec/).
These were mostly intended to prove the interpreters were working before they were capable of running real code.
The only real test suite that determines whether an interpreter works is the one made up of the Lox programs from the original test suites, as exposed by the `lox-test` program and defined in the `cases/` directory.
The choice to forgo unit test coverage is legitimate.
In the general case this is debatable, but in this one, I believe this is a relatively clear correct answer.
In my opinion, most of the negative properties of integration or end-to-end tests don't apply if the higher-level tests have already been written and are unlikely to change, meaning that the tradeoff between unit tests and other types of tests isn't acting like it normally would.

## How Closely Does This Match The Book's Materials?

In general: my implementations are very close to those of the book.

`lox-treewalker` is by and large a direct translation of `jlox` into Ruby, and generally uses the same concepts and abstractions.

`lox-bytecode` diverges a lot more from the original material, despite the main virtual machine also being written in C.
This is for a few reasons:

1. I chose not to have project-wide global variables for things like the current virtual machine.
   This had very significant repercussions, especially when combined with the additional runtime configurability.
1. My C code is structured in a quasi-OOP way, and I follow a very specific naming convention for functions.
   If you're getting the impression that I'm not a native C programmer, you're not wrong.
1. I basically don't use macros for anything more complex than constant definitions.
   This just reinforces that C is not my favorite programming language.

## Known Issues

- [`cases/field/many.lox`](cases/field/many.lox) currently fails with `lox-bytecode` because it causes my implementation to define too many constants.
  Reusing constants within a chunk would be the easiest way to make this work, but this would case [another test case to fail](cases/limit/no_reuse_constants.lox).
  I haven't decided what to do about this, but I would like to understand how `clox` avoids defining too many constants, as I believe my mistake is relatively subtle.

## Notable Omissions

There are a few features from the book that have not been implemented here.

### The Case Of The Missing Pratt Parser

Both interpreters use a recursive-descent parser, and there is no separate Pratt parser.
Using the same parsing frontend for both interpreters is practically the most important design decision in this entire project.
The Pratt parser is also not a straight translation of the book's materials because parsing and bytecode generation are expected to happen in different passes, rather than a single pass as in `clox`.
I've left room to add a Pratt parser in the future, but I don't expect to.

### No NaN Boxing

The bytecode interpreter doesn't use NaN boxing.
This is admittedly a very debatable decision, but I've made it for the following reasons:

1. Unlike in `clox`, it's not possible to scope the change to a few preprocessor changes with no impact after the virtual machine has been built.
   This is because the library needs to be callable from Ruby over FFI.
   It would be _possible_ to make NaN boxing a compile-defined property and require the same setting to be used when loading the shared library from Ruby, but it's not nearly as neat.
   Other alternatives may be even worse.
1. It might be more defensible to take the portability hit and make NaN boxing unconditional.
   This was tempting, but I also chose not to do this because I believe it would compromise some of the instructional value to me of the FFI bindings.
   I expect to refer to this project as an example of how to use the `ffi` gem to integrate with native extensions (because of how much less scattered it is than the official documentation), and `Value` is currently the only type with a `union` in the project.
1. The educational value of actually implementing NaN boxing in this project feels relatively small compared to that of doing everything else.

## Licensing

My new contributions to this project are [under the MIT license](LICENSE).

This project also contains files that are directly translated from those in the original Crafting Interpreters repository. These are also [under the MIT license, copyright 2015 Robert Nystrom](https://github.com/munificent/craftinginterpreters/blob/master/LICENSE).
