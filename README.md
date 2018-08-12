# Kleber CLI

This is the official command line client for Kleber. The main purpose is to provide a command line interface where the basic API features are implemented. Uploading of pure text as well as data/binary is supported from either files or STDIN.

## Installation

```
$ pip install -r requirements.txt
$ pit install .
```

### Packages

There is a [kleber-git](https://aur.archlinux.org/packages/kleber-git/) package in the Arch User Repository (AUR).

## Configuration

Kleber supports configuration files. The default configuration file is located at `~/.kleberrc`.

### Minimal Configuration File

A minimal configuration file includes just one line: a valid API key:

```
{"api_key": "$INSERT_API_KEY_HERE"}
```

### Uploading a File

```
$ kleber /bin/pwd
```

There is another, more convenient way to accomblish the same:

```
$ cat /bin/pwd | kleber - -n pwd
```

The name (-n) is optional.
