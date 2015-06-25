# Kleber CLI Client
This is the official command line client for Kleber. It is written in pure shell script and aims to be fully POSIX compliant.

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

##### Uplaod a file

```
$ kleber --upload /data/file
```

##### List upload history

```
$ kleber --list
```

##### Delete a paste

```
$ kleber --delete xyz
```

##### Get help

```
$ kleber --help
```

## Contribute
Feel free to open [issues](https://github.com/kleber-io/kleber-cli/issues) or create [pull requests](https://github.com/kleber-io/kleber-cli/pulls). Contributions are highly appreciated!
