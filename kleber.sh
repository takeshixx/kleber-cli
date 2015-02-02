#!/bin/sh

VERSION="0.0.1"

### Global variables (DO NOT CHANGE) ###################################################################################
DEBUG=0
KLEBER_WEB_URL="http://kleber.io"
KLEBER_API_URL="${KLEBER_WEB_URL}/api"
KLEBER_MAX_SIZE=262144000
KLEBER_RCFILE=~/.kleberrc

ARGS="$@"
ARGS_COUNT="$#"
USERAGENT="Kleber CLI client v${VERSION}"

tmpdir=$(mktemp -dt kleber.XXXXXX)
trap "rm -rf $tmpdir" EXIT TERM


### Helper functions based on NETBSD's rc.subr #########################################################################
err(){
    exitval=$1
    shift
    echo 1>&2 "$0: ERROR: $*"
    exit $exitval
}

warn(){
    echo 1>&2 "$0: WARNING: $*"
}

info(){
    echo "$0: INFO: $*"
}

debug(){
    case $DEBUG in
    [Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Oo][Nn]|1)
        echo 1>&2 "$0: DEBUG: $*"
        ;;
    esac
}

checkyesno(){
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
        warn "\$${1} is not set properly - see rc.conf(5)."
        return 1
        ;;
    esac
}


### General system functions ###########################################################################################
check_kernel(){
    if [ "$(uname -s)" != "FreeBSD" ]; then
        echo "[e] This script currently only supportes FreeBSD"
        exit 1
    fi
}

check_euid(){
    if [ "$(id -u)" = 0 ]; then
      err 1 "This script should not run with superuser privileges"
    fi
}

# Parsing command line arguments
cmdline(){
    arg=
    for arg
    do
        delim=""
        case "$arg" in
            #translate --gnu-long-options to -g (short options)
            --upload)         args="${args}-u ";;
            --delete)         args="${args}-d ";;
            --list)           args="${args}-l ";;
            --name)           args="${args}-n ";;
            --lifetime)       args="${args}-t ";;
            --offset)         args="${args}-o ";;
            --limit)          args="${args}-k ";;
            --web-link)          args="${args}-w ";;
            --config)         args="${args}-c ";;
            --help-config)    usage_config && exit 0;;
            --help)           args="${args}-h ";;
            --verbose)        args="${args}-v ";;
            --debug)          args="${args}-x ";;
            #pass through anything else
            *) [[ "${arg:0:1}" = "-" ]] || delim="\""
                args="${args}${delim}${arg}${delim} ";;
        esac
    done

    eval set -- $args

    while getopts "nvhd:xu:lc:t:n:o:k:w" OPTION
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
         v)
             VERBOSE=1
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

    return 0
}

load_config(){
    if [ -n "$CONFIG_FILE" ];then
        config=$CONFIG_FILE
    else
        config=$KLEBER_RCFILE
    fi

    if [ ! -r $config -o ! -f $config ];then
        err 1 "Cannot read config file ${config}"
    fi

    . $config

    return 0
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
    -v | --verbose                  Print verbose output
    -x | --debug                    Show debug output
!
}

read_stdin() {
    temp_file=$1
	if tty -s; then
		printf "%s\n" "^C to exit, ^D to send"
	fi
	cat > "$temp_file"
}

### Kleber functions ###################################################################################################
paste(){
    content=$1
    auth_header="X-Kleber-API-Auth: ${KLEBER_API_KEY}"
    request_url="${KLEBER_API_URL}/pastes}"
    if [ -n "$UPLOAD_NAME" ];then
        name="$UPLOAD_NAME"
    else
        name=""
    fi

    if [ -n "$UPLOAD_LIFETIME" ];then
        lifetime="$UPLOAD_LIFETIME"
    else
        lifetime="0"
    fi

    headerfile=$(mktemp "${tmpdir}/header.XXXXXX")
    post_data="{\"content\": \"${content}\", \"name\": \"${name}\", \"lifetime\": \"${lifetime}\"}"

    read status_code redirect_url <<!
    $(curl -# --tlsv1 --ipv4 -L --write-out '%{http_code} %{url_effective}' \
        --user-agent "$USERAGENT" \
        --header "Content-Type: application/json" \
        --dump-header "${headerfile}" \
        --header "$auth_header" \
        --data "$post_data" \
        --data-urlencode "$request_url"\
    )
!

    location="$(cat $headerfile|awk '/Location: (.*?)/ {print $2}')"
    shortcut="$(basename "$location")"

    if [ "$status_code" -eq "201" ];then
        debug "Upload successful"
        if [ -n "$WEB_LINK" -a "$WEB_LINK" = "1" ];then
            echo "${KLEBER_WEB_URL}/#/pastes/${shortcut}"
        else
            echo $location
        fi
    else
        handle_api_error "$status_code"
    fi

    return 0
}

upload(){
    file=$1
    auth_header="X-Kleber-API-Auth: ${KLEBER_API_KEY}"
    request_url="${KLEBER_API_URL}/pastes"

    if [ ! -r "$file" ];then
        err 1 "Cannot read file ${file}"
    elif [ "$(stat -c %s "${file}")" -eq 0 ];then
        err 1 "File size is 0"
    elif [ "$(stat -c %s "${file}")" -gt $KLEBER_MAX_SIZE ];then
        err 1 "File size exceeds maximum size"
    fi

    headerfile=$(mktemp "${tmpdir}/header.XXXXXX")

    read status_code redirect_url <<!
    $(curl -# --tlsv1 --ipv4 -L --write-out '%{http_code} %{url_effective}' \
        --user-agent "$USERAGENT" \
        --header "$auth_header" \
        --dump-header "${headerfile}" \
        -F "file=@${file}" "$request_url"\
    )
!

    location="$(cat $headerfile|awk '/Location: (.*?)/ {print $2}')"
    shortcut="$(basename "$location")"

    if [ "$status_code" -eq "201" ];then
        debug "Upload successful"
        if [ -n "$WEB_LINK" -a "$WEB_LINK" = "1" ];then
            echo "${KLEBER_WEB_URL}/#/pastes/${shortcut}"
        else
            echo $location
        fi
    else
        handle_api_error "$status_code"
    fi

    return 0
}

list(){
    offset="0"
    limit="10"
    auth_header="X-Kleber-API-Auth: ${KLEBER_API_KEY}"
    request_url="${KLEBER_API_URL}/pastes?offset=${offset}&limit=${limit}"

    if [ -n "$PAGINATION_OFFSET" ];then
        offset="$PAGINATION_OFFSET"
    elif [ -n "$PAGINATION_LIMIT" ];then
        limit="$PAGINATION_LIMIT"
    fi

    curl_out=$(curl --tlsv1 --ipv4 -L -s --user-agent "$USERAGENT" --header "$auth_header" "$request_url")

    echo $curl_out

    return 0
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

    return 0
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
        429)
            err 1 "Rate limit reached. Please try again later"
            ;;
        500)
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
    cmdline $ARGS
    load_config

    if [ -n "$COMMAND_UPLOAD" ];then
        upload "$COMMAND_UPLOAD"
    elif [ -n "$COMMAND_DELETE" ];then
        delete "$COMMAND_DELETE"
    elif [ -n "$COMMAND_LIST" ];then
        list
    elif [ "$ARGS_COUNT" -eq 0 ];then
        tmpfile=$(mktemp "${tmpdir}/data.XXXXXX")
        read_stdin "$tmpfile"
        upload "$tmpfile"
    fi

    return 0
}

main