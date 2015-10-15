# Kleber CLI
This is the official command line client for Kleber. It is written in pure shell script and aims to be fully POSIX compliant. The main purpose is to provide a command line interface where the basic API features are implemented. Uploading of pure text as well as data/binary is supported from either files or STDIN.

## Installation

```
$ git clone https://github.com/kleber-io/kleber-cli.git
$ cd kleber-cli
# make install
```

## Configuration
Kleber supports configuration files. The default configuration file is located at `~/.kleberrc`. Any variables of the CLI
can be overwritten with configuration files, so modifying the code in order to change it's behaviour is not necessary.

### Minimal Configuration File
A minimal configuration file includes just one line: a valid API key:

```
KLEBER_API_KEY=APIKEY
```

## Usage

```
Kleber command line client
usage: [cat |] kleber.sh [command] [options] [file|shortcut]

Commands:
    -u | --upload <file>            Upload a file
    -d | --delete <shortcut>        Delete a paste/file
    -l | --list                     Print upload history

Options:
    -n | --name <name>              Name/Title for a paste
    -s | --secure-url               Create with secure URL
    -t | --lifetime <lifetime>      Set upload lifetimes (in seconds)
    -o | --offset <offset>          Pagination offset (default: 0)
    -k | --limit <limit>            Pagination limit (default: 10)
    -g | --no-lexer                 Don't guess a lexer for text files
    -c | --config                   Provide a custom config file (default: ~/.kleberrc)
    -C | --curl-config              Read curl config from stdin
    -a | --api-url                  Return API URL
    -h | --help                     Show this help
    -q | --quiet                    Suppress output
    -x | --debug                    Show debug output
```

### Uploading a file

```
$ kleber --upload /bin/pwd
```

There is another, more convenient way to accomblish the same:

```
$ cat /bin/pwd | kleber -n pwd
```

The name (-n) is optional.

## Contribute
Feel free to open [issues](https://github.com/kleber-io/kleber-cli/issues) or create [pull requests](https://github.com/kleber-io/kleber-cli/pulls). Contributions are highly appreciated!
