# Grit

**Grit is a simple build automation tool inspired by Make. It is currently still far from being finished and only supports simple variable expansion and command execution and a few extra features you can learn more about down below.**

## Installation

### Option 1 - Build it yourself

```sh
git clone https://github.com/sebii16/grit-build-tool
cd grit
zig build-exe src/main.zig -O ReleaseSmall -lc
```
> [!IMPORTANT]
> Grit requires Zig 0.16.0. Other versions are currently unsupported.

## Example

`build.grit`

```sh
# Variable declarations
SRC = "src/main.zig"
OUT = "grit.exe"
FLAGS = "-O ReleaseSmall -fstrip -lc"

# Default rule
@default
build {
    "zig build-exe $SRC -femit-bin=$OUT $FLAGS"
}

# 2nd rule
other_rule {
    'echo "Hello world"'
}
```

**Run the default rule:**

```sh
grit
```

**Run a different rule:**

```sh
grit other_rule
```

**Run a different build file:**

```sh
grit -f file_name
```

## Flags

```text
Build flags:
-d, --dry       Print commands without executing them.
--noexpand      Disable variable expansion.
-f, --file      Specify the build file.
-r, --rule      Specify the build rule.
--ignore-errors Treat execution errors as warnings.

Global flags: 
-h, --help      Show help message.
-v, --version   Show version and license information.
-l, --list      List build rules.
```

> [!NOTE]
> Grit is currently experimental and under active development.
> Build file syntax and general behavior may change between releases.