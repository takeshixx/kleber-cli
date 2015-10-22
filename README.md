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

### Optional Dependencies

* [jq](https://stedolan.github.io/jq/) (history printing)
* [xclip](http://sourceforge.net/projects/xclip/) (copy links to clipboard)
* [exiftool](http://www.sno.phy.queensu.ca/~phil/exiftool/) (remove metadata locally)

## Configuration
Kleber supports configuration files. The default configuration file is located at `~/.kleberrc`. Any variables of the CLI
can be overwritten with configuration files, so modifying the code in order to change it's behaviour is not necessary.

### Minimal Configuration File
A minimal configuration file includes just one line: a valid API key:

```
KLEBER_API_KEY=$INSERT_API_KEY_HERE
```

A a basic configuration file, could look like this:


```
KLEBER_API_URL=https://kleber.io/api
KLEBER_API_URL_TOR=http://6pvvph7kvxexq2e2.onion/api
KLEBER_API_KEY=$INSERT_API_KEY_HERE
```

## Usage

```
Kleber command line client
usage: [cat |] kleber.sh [command] [options] [file|shortcut]

Commands:
    -u | --upload <file>            Upload a file
    -d | --delete <shortcut>        Delete a paste/file
    -l | --list                     Print upload history
    -e | --remove-meta <file|dir>   Remove metadata from a regular file or directory.
                                    This requires exiftool to be installed in $PATH.

Upload Options:
    -n | --name <name>              Name/Title for a paste
    -s | --secure-url               Create with secure URL
    -t | --lifetime <lifetime>      Set upload lifetimes (in seconds)
    -g | --no-lexer                 Don't guess a lexer for text files
    -p | --print-api-url            Return web instead of API URL

List Options:
    -o | --offset <offset>          Pagination offset (default: 0)
    -k | --limit <limit>            Pagination limit (default: 10)

General Options:
    -y | --tor                      Enable TOR support
    -z | --tor-proxy <ip:port>      IP and port if TOR proxy (default: 127.0.0.1:9150)
    -a | --api-url                  Set API URL (default: https://kleber.io/api)
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

### Using the Hidden Service API via TOR

The CLI also works for the hidden service API accessible via the TOR network:

```
$ kleber --list --tor
```

This will try to list the pastes via the hidden service API. It uses the default TOR proxy settings `localhost:9150`. This can be changed:

```
$ kleber --list --tor-proxy 127.0.0.1:9151
```

In case the API URL will change in the future, it can either be changed set in the `~/.kleberrc` config file, or via the `--api-url` paramter:
    
```
$ kleber --list --tor --api-url https://aiojsdioiajosjdo.onion/api
```

### HTTP Proxy Support

Because the CLI is basically just a wrapper around curl, HTTP proxies can be supplied via environment variables:

```
$ export HTTP_PROXY=http://192.168.1.1:8080
$ kleber --list
```

## Contribute
Feel free to open [issues](https://github.com/kleber-io/kleber-cli/issues) or create [pull requests](https://github.com/kleber-io/kleber-cli/pulls). Contributions are highly appreciated!
