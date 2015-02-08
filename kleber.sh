#!/bin/sh
# --
# Kleber (kleber.io) command line client
#
# Version:      v0.0.1-alpha
# Home:         https://github.com/takeshixx/kleber-cli
# License:      GPLv3 (see LICENSE for full license text)
#
#
# Usage:        kleber --help
# --

set -e

### Global variables (DO NOT CHANGE) ###################################################################################
VERSION="0.0.1-alpha"
DEBUG=0
KLEBER_WEB_URL="http://kleber.io"
KLEBER_API_URL="${KLEBER_WEB_URL}/api"
KLEBER_MAX_SIZE=262144000
KLEBER_RCFILE=~/.kleberrc

ARGS="$*"
ARGS_COUNT="$#"
USERAGENT="Kleber CLI client v${VERSION}"
CLIPPER=
CLIPPER_CMD=
TMPDIR=$(mktemp -dt kleber.XXXXXX)

trap "rm -rf '$TMPDIR'" EXIT TERM


### Helper functions based on NETBSD's rc.subr #########################################################################
err(){
    exitval=$1
    shift
    echo 1>&2 "ERROR: $*"
    exit "$exitval"
}

warn(){
    echo 1>&2 "WARNING: $*"
}

info(){
    if [ -z $QUIET ] || checkseyno $QUIET;then
        echo -e "$*"
    fi
}

debug(){
    case $DEBUG in
    [Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Oo][Nn]|1)
        echo 1>&2 "DEBUG: $*"
        ;;
    esac
}

checkyesno(){
    if [ -z "$1" ];then
        return 1
    fi
    eval _value=\$${1}
    debug "checkyesno: $1 is set to $_value."
    case $_value in
        #   "yes", "true", "on", or "1"
    [Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Oo][Nn]|1)
        return 0
        ;;
        #   "no", "false", "off", or "0"
    [Nn][Oo]|[Ff][Aa][Ll][Ss][Ee]|[Oo][Ff][Ff]|0)
        return 1
        ;;
    *)
        return 1
        ;;
    esac
}


### General system functions ###########################################################################################
check_euid(){
    if [ "$(id -u)" = 0 ]; then
      err 1 "This script should not run with superuser privileges"
    fi
}

check_dependencies(){
    if ! which curl >/dev/null;then
        err 1 "Kleber CLI needs curl, please install it"
    fi

    if which xclip >/dev/null;then
        CLIPPER=1
        CLIPPER_CMD="xclip -selection clipboard"
    else
        CLIPPER=0
    fi
}

cmdline(){
    arg=
    for arg
    do
        delim=""
        case "$arg" in
            --upload)         args="${args}-u ";;
            --delete)         args="${args}-d ";;
            --list)           args="${args}-l ";;
            --name)           args="${args}-n ";;
            --lifetime)       args="${args}-t ";;
            --offset)         args="${args}-o ";;
            --limit)          args="${args}-k ";;
            --clipboard)      args="${args}-p ";;
            --web-link)       args="${args}-w ";;
            --config)         args="${args}-c ";;
            --help)           args="${args}-h ";;
            --quiet)          args="${args}-q ";;
            --debug)          args="${args}-x ";;
            *)
                if [ ! "$(expr substr "${arg}" 0 1)" = "-" ];then
                    delim="\""
                fi
                args="${args}${delim}${arg}${delim} ";;
        esac
    done

    eval set -- $args

    while getopts "whlpd:xu:c:t:n:o:k:" OPTION
    do
         case $OPTION in
         u)
            COMMAND_UPLOAD=$OPTARG
            ;;
         d)
            COMMAND_DELETE=$OPTARG
            ;;
         l)
            COMMAND_LIST=1
            ;;
         n)
            UPLOAD_NAME=$OPTARG
            ;;
         t)
            UPLOAD_LIFETIME=$OPTARG
            ;;
         o)
            PAGINATION_OFFSET=$OPTARG
            ;;
         k)
            PAGINATION_LIMIT=$OPTARG
            ;;
         w)
            WEB_LINK=1
            ;;
         p)
            KLEBER_CLIPBOARD_DEFAULT=1
            ;;
         q)
            QUIET=1
            ;;
         h)
             help
             exit 0
             ;;
         x)
             DEBUG=1
             set -x
             ;;
         c)
             CONFIG_FILE=$OPTARG
             ;;
        esac
    done
}

load_config(){
    if [ -n "$CONFIG_FILE" ];then
        config=$CONFIG_FILE
    else
        config=$KLEBER_RCFILE
    fi

    if [ ! -r $config ] || [ ! -f $config ];then
        err 1 "Cannot read config file ${config}"
    fi


    if [ -n "$KLEBER_API_KEY" ];then
        err 1 "API key not found. Pleaase put it in the config file."
    fi

    . $config
}

read_stdin() {
    temp_file=$1
	if tty -s; then
		printf "%s\n" "^C to exit, ^D to send"
	fi
	cat > "$temp_file"
}


help() {
	cat <<!
Kleber command line client
usage: [cat |] $(basename "$0") [command] [options] [file|shortcut]

Commands:
    -u | --upload <file>            Upload a file
    -d | --delete <shortcut>        Delete a paste/file
    -l | --list                     Print upload history

Options:
    -n | --name <name>              Name/Title for a paste
    -w | --web-link                 Return web instead of API URL
    -t | --lifetime <lifetime>      Set upload lifetimes (in seconds)
    -o | --offset <offset>          Pagination offset (default: 0)
    -k | --limit <limit>            Pagination limit (default: 10)
    -h | --help                     Show this help
    -c | --config                   Provide a custom config file (default: ~/.kleberrc)
    -q | --quiet                    Suppress output
    -x | --debug                    Show debug output
!
}


### Kleber functions ###################################################################################################
upload(){
    file=$1
    auth_header="X-Kleber-API-Auth: ${KLEBER_API_KEY}"
    request_url="${KLEBER_API_URL}/pastes"
    headerfile=$(mktemp "${TMPDIR}/header.XXXXXX")
    filestr="file=@${file}"

    if [ ! -r "$file" ];then
        err 1 "Cannot read file ${file}"
    elif [ "$(stat -c %s "${file}")" -eq 0 ];then
        err 1 "File size is 0"
    elif [ "$(stat -c %s "${file}")" -gt $KLEBER_MAX_SIZE ];then
        err 1 "File size exceeds maximum size"
    fi

    if [ -n "$UPLOAD_NAME" ];then
        filestr="${filestr};filename=${UPLOAD_NAME}"
    fi

    curl_out=$(curl --progress-bar --tlsv1 --ipv4 -L --write-out '%{http_code} %{url_effective}' \
        --user-agent "$USERAGENT" \
        --header "$auth_header" \
        --header "Expect:" \
        --dump-header "${headerfile}" \
        -F "${filestr}" \
        "$request_url"\
    )

    status_code="$(awk '/^HTTP\/1.1\s[0-9]{3}\s/ {print $2}' ${headerfile})"

    if [ -n "$status_code" ] && [ "$status_code" -eq "201" ];then
        debug "Upload successful"
        location="$(awk '/Location: (.*?)/ {print $2}' ${headerfile})"
        shortcut="$(basename "$location")"

        if checkyesno "$WEB_LINK";then
            location="${KLEBER_WEB_URL}/#/pastes/${shortcut}"
            info "$location"
            copy_to_clipper "$location"
        else
            info "${location}"
            copy_to_clipper "$location"
        fi
    else
        handle_api_error "$status_code"
    fi
}

list(){
    offset="0"
    limit="10"
    auth_header="X-Kleber-API-Auth: ${KLEBER_API_KEY}"

    if [ -n "$PAGINATION_OFFSET" ];then
        offset="$PAGINATION_OFFSET"
    fi
    if [ -n "$PAGINATION_LIMIT" ];then
        limit="$PAGINATION_LIMIT"
    fi

    request_url="${KLEBER_API_URL}/pastes?offset=${offset}&limit=${limit}"
    curl_out=$(curl --tlsv1 --ipv4 -L -s --user-agent "$USERAGENT" --header "$auth_header" "$request_url")

    echo "$curl_out"
}

delete(){
    shortcut=$1
    auth_header="X-Kleber-API-Auth: ${KLEBER_API_KEY}"
    request_url="${KLEBER_API_URL}/pastes/${shortcut}"
    status_code=$(curl -s -X DELETE --tlsv1 --ipv4 -L \
        --write-out '%{http_code}' \
        --header "$auth_header" "$request_url" |grep -Po "[0-9]{3}$"
    )

    if [ "$status_code" -eq "204" ];then
        debug "Upload successfully deleted"
    else
        handle_api_error "$status_code"
    fi
}

copy_to_clipper(){
    location=$1

    if checkyesno "$KLEBER_CLIPBOARD_DEFAULT";then
        if checkyesno "$CLIPPER";then
            echo "$location" | eval "${CLIPPER_CMD}" || return 1
        else
            warn "xclip not found"
        fi
    fi
}

handle_api_error(){
    status_code=$1

    case $status_code in
        400)
            err 1 "Invalid request data"
            ;;
        401)
            err 1 "Invalid or missing authentication token"
            ;;
        403)
            err 1 "You are not authorized to access this resource"
            ;;
        404)
            err 1 "Resource not found"
            ;;
        413)
            err 1 "Request entity too large"
            ;;
        429)
            err 1 "Rate limit reached. Please try again later"
            ;;
        500)p
            err 1 "An error occured. Please try again later"
            ;;
        503)
            err 1 "API currently not available. Please try again later"
            ;;
        *)
            err 1 "Unknown error"
            ;;
    esac
}


### Main application logic #############################################################################################
main(){
    check_euid
    check_dependencies
    cmdline $ARGS
    load_config

    if [ -n "$COMMAND_UPLOAD" ];then
        upload "$COMMAND_UPLOAD"
    elif [ -n "$COMMAND_DELETE" ];then
        delete "$COMMAND_DELETE"
    elif [ -n "$COMMAND_LIST" ];then
        list
    else
        tmpfile=$(mktemp "${TMPDIR}/data.XXXXXX")
        read_stdin "$tmpfile"
        upload "$tmpfile"
    fi

    return 0
}

main