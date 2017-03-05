# Kleber CLI
This is the official command line client for Kleber. It is written in pure shell script and aims to be fully POSIX compliant. The main purpose is to provide a command line interface where the basic API features are implemented. Uploading of pure text as well as data/binary is supported from either files or STDIN.

## Installation

```
$ git clone https://github.com/kleber-io/kleber-cli.git
$ cd kleber-cli
# make install
```

### Dependencies

* [curl](http://curl.haxx.se/)
* [jq](https://stedolan.github.io/jq/) (history printing)

### Optional Dependencies

* [xclip](http://sourceforge.net/projects/xclip/) (automatically copy links to clipboard)
* [exiftool](http://www.sno.phy.queensu.ca/~phil/exiftool/) (remove metadata locally)

## Configuration
Kleber supports configuration files. The default configuration file is located at `~/.kleberrc`. Any variables of the CLI
can be overwritten with configuration files, so modifying the code in order to change it's behaviour is not necessary.

### Minimal Configuration File
A minimal configuration file includes just one line: a valid API key:

```
KLEBER_API_KEY=$INSERT_API_KEY_HERE
```

A basic configuration file could look like this:


```
KLEBER_API_URL=https://kleber.io/api
KLEBER_API_KEY=$INSERT_API_KEY_HERE
```

## Usage

```
Kleber (kleber.io) API CLI v0.7.0
usage: [cat |] kleber [command] [options] [file|shortcut]

Commands:
    -u | --upload <file>            Upload a file
    -g | --get <file>               Get a file
    -d | --delete <shortcut>        Delete a paste/file
    -l | --list                     Print upload history
    -e | --remove-meta <file|dir>   Remove metadata from a regular file or directory.
                                    This requires exiftool to be installed in $PATH.
    -b | --upload-screenshot        Take a screenshot and upload it.

Upload Options:
    -n | --name <name>              Name/Title for a paste
    -s | --secure-url               Create with secure URL
    -t | --lifetime <lifetime>      Set upload lifetimes (in seconds)
    -f | --print-api-url            Return API URL instead of web URL
    -w | --password                 Protect upload with password

Get Options:
    -o | --output <location>        Output location (default: current directory)

List Options:
    -o | --offset <offset>          Pagination offset (default: 0)
    -k | --limit <limit>            Pagination limit (default: 10)

General Options:
    -p | --clipboard                Add document link to clipboard
    -a | --url                      Set alternative URL (default: https://kleber.io/)
    -c | --config                   Provide a custom config file (default: ~/.kleberrc)
    -C | --curl-config              Read curl config from stdin
    -q | --quiet                    Suppress output
    -x | --debug                    Show debug output
    -h | --help                     Show this help
```

### Uploading a File

```
$ kleber --upload /bin/pwd
```

There is another, more convenient way to accomblish the same:

```
$ cat /bin/pwd | kleber -n pwd
```

The name (-n) is optional.

### HTTP Proxy Support

Because the CLI is basically just a wrapper around curl, HTTP proxies can be supplied via environment variables:

```
$ export HTTP_PROXY=http://192.168.1.1:8080
$ kleber --list
```

## Contribute
Feel free to open [issues](https://github.com/kleber-io/kleber-cli/issues) or create [pull requests](https://github.com/kleber-io/kleber-cli/pulls). Contributions are highly appreciated!
