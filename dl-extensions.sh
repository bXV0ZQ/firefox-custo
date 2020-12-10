#!/usr/bin/bash

SCRIPT_NAME=$(basename $0)

#
# CONFIGURATION
#

# Default values
declare -r DEF_EXT_LST="./extensions.lst"
declare -r DEF_EXT_DIR="./extensions"

#
# UTILS
#

RED="\\033[1;31m"
GREEN="\\033[1;32m"
YELLOW="\\033[1;33m"
BLUE="\\033[1;34m"
MAGENTA="\\033[1;35m"
CYAN="\\033[1;36m"
BOLD="\\033[1m"
END="\\033[1;00m"
FATAL="\\033[1;37;41m" # WHITE on RED

print_info () {
    echo -e "${GREEN} [INFO]${END} $@"
}

print_error () {
    echo -e "${RED} [ERROR]${END} $@"
}

print_warn () {
    echo -e "${YELLOW} [WARN]${END} $@"
}

print_step () {
    echo -e "${MAGENTA} >>>${END} $@"
}

print_sub_step () {
    echo -e "${MAGENTA} >>>>>>${END} $@"
}


usage () {
    local USAGE

# \n is required to preserve whitespaces for the first line (and adding a new line before printing the usage message is a good deal)
    read -r -d '' USAGE << EOM
\n    Usage: ${SCRIPT_NAME} [-l <extensions_list>] [-o <extensions_folder>]

    Extract lastest version of ${YELLOW}firefox extensions${END} listed in ${BOLD}<extensions_list>${END} to ${BOLD}<extensions_folder>${END} with the correct name (based on gecko ID).
    
    Options:
        -l|--ext-list ${BOLD}<extensions_list>${END}
            A file containing a list of extension's name, one per line, as per the Extension URL from AMO (addons.mozilla.org).
            e.g. https://addons.mozilla.org/en-US/firefox/addon/<myextension>/
        
        -o|--ext-output ${BOLD}<extensions_folder>${END}
            The folder where extension will be downloaded
    
    Others:
        -h|--help: print this help message

EOM
    echo -e "${USAGE}"
}

#
# RETRIEVE INPUT
#

# Need help?
case "$1" in
    "-h"|"--help") usage && exit 0;;
esac

# Look for options
while [[ -n "$1" ]]; do
    case "$1" in
        "-l"|"--ext-list")
            if [[ $# -ge 2 ]]; then
                ARG_EXT_LST="$2"
                shift 2
            else
                print_error "Missing extensions list after '$1'" && usage && exit 1
            fi
            ;;
        "-o"|"--ext-output")
            if [[ $# -ge 2 ]]; then
                ARG_EXT_DIR="$2"
                shift 2
            else
                print_error "Missing extensions output folder after '$1'" && usage && exit 1
            fi
            ;;
        "-h"|"--help") usage && exit 0;;
        *) print_error "Unknown command '$1'" && usage && exit 1;;
    esac
done

# Prepare options
EXT_LST=${ARG_EXT_LST:-${DEF_EXT_LST}}
EXT_DIR=${ARG_EXT_DIR:-${DEF_EXT_DIR}}

#
# INPUT VALIDATION
#

# Validate SALT_ROOT
[[ ! -f "${EXT_LST}" ]] && print_error "Invalid extensions list (file doesn't exist): '${EXT_LST}'" && usage && exit 1

# Validate SRC_DIR
[[ ! -d "${EXT_DIR}" ]] && print_error "Invalid extensions output folder (folder doesn't exist): '${EXT_DIR}'" && usage && exit 1

#
# MAIN PROCESS
#

while read e || [[ -n ${e} ]]; do
  print_step "Processing '${e}'"
  EXT_SRC="https://addons.mozilla.org/firefox/downloads/latest/${e}/latest.xpi"
  EXT_DL="${EXT_DIR}/${e}.xpi"
  EXT_INFO="${EXT_DIR}/${e}.info"
  wget "${EXT_SRC}" -O "${EXT_DL}" >/dev/null 2>&1
  EXT_HASH=$(sha256sum "${EXT_DL}" | cut -d' ' -f1)
  if [[ $? -eq 0 ]]; then
    print_info "Extension downloaded"
    EXT_ID=""
    if [[ -z "${EXT_ID}" ]]; then
        tmp_id=$(unzip -p "${EXT_DL}" manifest.json | jq -r -e '.applications.gecko.id')
        if [[ $? -eq 0 ]]; then
            EXT_ID="${tmp_id}"
        fi
    fi
    if [[ -z "${EXT_ID}" ]]; then
        tmp_id=$(unzip -p "${EXT_DL}" manifest.json | jq -r -e '.browser_specific_settings.gecko.id')
        if [[ $? -eq 0 ]]; then
            EXT_ID="${tmp_id}"
        fi
    fi
    if [[ -z "${EXT_ID}" ]]; then
        tmp_id=$(unzip -p "${EXT_DL}" mozilla-recommendation.json | jq -r -e '.addon_id')
        if [[ $? -eq 0 ]]; then
            EXT_ID="${tmp_id}"
        fi
    fi
    if [[ -n "${EXT_ID}" ]]; then
        echo "${e}:" > "${EXT_INFO}"
        echo "  id: ${EXT_ID}" >> "${EXT_INFO}"
        echo "  source: ${EXT_SRC}" >> "${EXT_INFO}"
        echo "  hash: ${EXT_HASH}" >> "${EXT_INFO}"
        print_info "Extension info generated"
    else
        print_error "Impossible to get the addon ID of the extension"
    fi
  else
    print_error "Extension download failed"
  fi
done < "${EXT_LST}"
