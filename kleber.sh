#!/bin/sh
# --
# Kleber (kleber.io) API CLI
#
# Home:         https://github.com/kleber-io/kleber-cli
# License:      GPLv3 (see LICENSE for full license text)
# Usage:        kleber --help
# --
set -e
ARGS="$*"
VERSION="0.5.4"
KLEBER_URL="https://kleber.io"
KLEBER_API_URL="${KLEBER_URL}/api"
KLEBER_URL_TOR="http://6pvvph7kvxexq2e2.onion"
KLEBER_API_URL_TOR="${KLEBER_URL_TOR}/api"
KLEBER_MAX_SIZE=262144000
KLEBER_RCFILE=~/.kleberrc
UPLOAD_LIFETIME=604800
USERAGENT="Kleber CLI client v${VERSION}"
CLIPPER=
CLIPPER_CMD=
DEBUG=0
SECURE_URL=0
NO_LEXER=0
EXIFTOOL=0
API_URL=0
URL_EXT=0
USE_TOR=0
TOR_PROXY="127.0.0.1:9150"
JQ_BIN=0
RAW_HISTORY=0
TMPDIR=$(mktemp -dt kleber.XXXXXX)
trap "rm -rf '$TMPDIR'" EXIT TERM

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
    if [ -z "$QUIET" ] || checkseyno "$QUIET";then
        echo "$*"
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

check_euid(){
    if [ "$(id -u)" = 0 ]; then
      warn "You should not run this with superuser privileges!"
      read -r
    fi
}

check_dependencies(){
    if ! which curl >/dev/null;then
        err 1 "Kleber CLI needs curl, please install it."
    fi

    if which xclip >/dev/null;then
        CLIPPER=1
        CLIPPER_CMD="xclip -selection clipboard"
    else
        CLIPPER=0
    fi

    if which jq >/dev/null;then
        JQ_BIN=1
    fi
}

is_url(){
    url_regex="(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]"
    if [[ "$1" =~ "$url_regex" ]];then
        return 1
    else
        return 0
    fi
}

is_ip4(){
    ip4_regex="[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"
    if [[ "$1" =~ "$ip4_regex" ]];then
        return 1
    else
        return 0
    fi
}

cmdline(){
    arg=
    for arg
    do
        delim=""
        case "$arg" in
            --debug)          args="${args}-x ";;
            --upload)         args="${args}-u ";;
            --delete)         args="${args}-d ";;
            --list)           args="${args}-l ";;
            --api-url)        args="${args}-a ";;
            --tor)            args="${args}-y ";;
            --tor-proxy)      args="${args}-z ";;
            --remove-meta)    args="${args}-e ";;
            --name)           args="${args}-n ";;
            --lifetime)       args="${args}-t ";;
            --offset)         args="${args}-o ";;
            --limit)          args="${args}-k ";;
            --clipboard)      args="${args}-p ";;
            --raw-history)    args="${args}-r ";;
            --secure-url)     args="${args}-s ";;
            --config)         args="${args}-c ";;
            --curl-config)    args="${args}-C ";;
            --print-api-url)  args="${args}-f ";;
            --help)           args="${args}-h ";;
            --quiet)          args="${args}-q ";;
            *)
                if [ ! "$(expr substr "${arg}" 0 1)" = "-" ];then
                    delim="\""
                fi
                args="${args}${delim}${arg}${delim} ";;
        esac
    done

    eval set -- "$args"

    while getopts "xhlpd:u:c:Ct:n:o:k:sga:e:pyz:rf" OPTION
    do
        case $OPTION in
         x)
            DEBUG=1
            set -x
            ;;
         q)
            QUIET=1
            ;;
         u)
            COMMAND_UPLOAD=$OPTARG
            ;;
         d)
            COMMAND_DELETE=$OPTARG
            ;;
         l)
            COMMAND_LIST=1
            ;;
         a)
            URL_EXT=$OPTARG
            if ! is_url "$URL_EXT";then
                err 1 "Invalid URL ${URL_EXT}"
            fi
            ;;
         e)
            if ! which exiftool >/dev/null;then
                err 1 "exiftool not found"
            fi

            EXIFTOOL=$(which exiftool)
            EXIFTOOL_INPUT=$OPTARG
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
         s)
            SECURE_URL=1
            ;;
         p)
            KLEBER_CLIPBOARD_DEFAULT=1
            ;;
         r)
            RAW_HISTORY=1
            ;;
         g)
            NO_LEXER=1
            ;;
         y)
            USE_TOR=1
            ;;
         z)
            arr=($(echo "$OPTARG" | tr ":" "\n"))
            if [ ${#arr[@]} != 2 ];then
                err 1 "Invalid proxy format. Example: '127.0.0.1:1234'"
            fi

            if ! is_ip4 ${arr[0]};then
                err 1 "Invalid IP address ${arr[0]}"
            fi

            USE_TOR=1
            TOR_PROXY=$OPTARG
            ;;
         c)
            CONFIG_FILE=$OPTARG
            ;;
         f)
            API_URL=1
            ;;
         h)
            help
            exit 0
            ;;
         *)
            help
            exit 1
            ;;
        esac
    done
}

help() {
	cat <<!
Kleber (kleber.io) API CLI
usage: [cat |] $(basename "$0") [command] [options] [file|shortcut]

Commands:
    -u | --upload <file>            Upload a file
    -d | --delete <shortcut>        Delete a paste/file
    -l | --list                     Print upload history
    -e | --remove-meta <file|dir>   Remove metadata from a regular file or directory.
                                    This requires exiftool to be installed in \$PATH.

Upload Options:
    -n | --name <name>              Name/Title for a paste
    -s | --secure-url               Create with secure URL
    -t | --lifetime <lifetime>      Set upload lifetimes (in seconds)
    -g | --no-lexer                 Don't guess a lexer for text files
    -f | --print-api-url            Return API URL instead of web URL

List Options:
    -o | --offset <offset>          Pagination offset (default: 0)
    -k | --limit <limit>            Pagination limit (default: 10)
    -r | --raw-history              Print the raw history response (without jq formatting)

General Options:
    -y | --tor                      Enable TOR support
    -z | --tor-proxy <ip:port>      IP and port if TOR proxy (default: 127.0.0.1:9150)
    -a | --url                      Set alternative URL (default: https://kleber.io/)
    -c | --config                   Provide a custom config file (default: ~/.kleberrc)
    -C | --curl-config              Read curl config from stdin
    -q | --quiet                    Suppress output
    -x | --debug                    Show debug output
    -h | --help                     Show this help
!
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

    if checkyesno "$USE_TOR";then
        if [ "$URL_EXT" != 0 ];then
            KLEBER_URL="$URL_EXT"
            KLEBER_API_URL="${URL_EXT}/api"
        else
            KLEBER_URL="$KLEBER_URL_TOR"
            KLEBER_API_URL="$KLEBER_API_URL_TOR"
        fi
    fi
}

read_stdin() {
    temp_file=$1
	if tty -s; then
        printf "%s\n" "^C to exit, ^D to send"
	fi
	cat > "$temp_file"
}

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

    if checkyesno "$SECURE_URL";then
        SECURE_URL="secureUrl=true"
    else
        SECURE_URL="secureUrl=false"
    fi

    if checkyesno "$NO_LEXER";then
        NO_LEXER="lexer="
    else
        NO_LEXER="lexer=auto"
    fi

    if checkyesno "$USE_TOR";then
        tor_setup="--socks5-hostname ${TOR_PROXY}"
    fi

    curl_out=$(eval "curl \
        --progress-bar \
        --tlsv1 \
        -L \
        --write-out '%{http_code} %{url_effective}' \
        --user-agent \"$USERAGENT\" \
        --header \"$auth_header\" \
        --header \"Expect:\" \
        --dump-header $headerfile \
        --form $SECURE_URL \
        --form lifetime=${UPLOAD_LIFETIME} \
        --form $NO_LEXER \
        --form \"${filestr}\" \
        $tor_setup \
        $request_url \
    ")

    status_code="$(awk '/^HTTP\/1.1\s[0-9]{3}\s/ {print $2}' ${headerfile})"

    if [ -n "$status_code" ] && [ "$status_code" = "201" ];then
        debug "Upload successful"
        location="$(awk '/Location: (.*?)/ {print $2}' ${headerfile})"

        if checkyesno "$API_URL";then
            shortcut="$(echo $location | awk -F/ '{print $4}')"
            location="${KLEBER_API_URL}/pastes/${shortcut}"
        fi

        shortcut="$(basename "$location")"

        info "${location}"
        copy_to_clipper "$location"
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

    if checkyesno "$USE_TOR";then
        tor_setup="--socks5-hostname ${TOR_PROXY}"
    fi

    request_url="${KLEBER_API_URL}/pastes?offset=${offset}&limit=${limit}"
    curl_out=$(eval "curl \
        ${CURL_CONFIG_STDIN} \
        --tlsv1 \
        -L \
        -s \
        --user-agent \"${USERAGENT}\" \
        --header \"${auth_header}\" \
        ${tor_setup} \
        ${request_url} \
    ")

    if checkyesno "$JQ_BIN" && ! checkyesno "$RAW_HISTORY";then
        echo "$curl_out" | jq ".documents[] | { shortcut, name, size, mimeType, date, "url": .url."web" }"
    elif ! checkyesno "$JQ_BIN" && checkyesno "$RAW_HISTORY";then
        echo "Please install jq for proper history printing."
        echo "$curl_out"
    else
        echo "$curl_out"
    fi
}

delete(){
    shortcut=$1
    auth_header="X-Kleber-API-Auth: ${KLEBER_API_KEY}"
    request_url="${KLEBER_API_URL}/pastes/${shortcut}"
    status_code=$(eval "curl \
        ${CURL_CONFIG_STDIN} \
        -s \
        -X DELETE \
        --tlsv1 \
        -L \
        --write-out '%{http_code}' \
        --header \"$auth_header\" \
        $request_url" |grep -Po "[0-9]{3}$"
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

remove_meta(){
    # A very simple exiftool wrapper that removes all metadata it knows.
    input=$1
    
    if [ -f "$input" ];then
        $EXIFTOOL -all= "$input" >/dev/null 2>&1
        RET=$?
    elif [ -d "$input" ];then
        $EXIFTOOL -r -all= "$input" >/dev/null 2>&1
        RET=$?
    else
        err 1 "You need to supply a regular file or a directory."
    fi

    if [ "$RET" = 0 ];then
        info "Metadata removed"
    else
        err 1 "Removing metadata failed!"
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
            err 1 "Unknown API error"
            ;;
    esac
}

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
    elif [ "$EXIFTOOL" != 0 ];then
        remove_meta "$EXIFTOOL_INPUT"
    else
        tmpfile=$(mktemp "${TMPDIR}/data.XXXXXX")
        read_stdin "$tmpfile"
        upload "$tmpfile"
    fi

    return 0
}

main
