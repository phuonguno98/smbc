#! /bin/bash

#
# Synchronize MinIO Buckets Content
# Written by Nguyen Thanh Phuong
# Version 1.0.0
# Release date: Sun 25 Jun 2023 11:38:28 AM +07
#

# Declare global variables.
VERSION="1.0.0"
LOG_FILE="/var/log/smbc/sync_minio-$(whoami).log"
ERROR_LOG_FILE="/var/log/smbc/sync_minio.error"
CONFIG_PATH="/etc/smbc/"
TIMESTAMP=$(date +"%F %T")
MSG_INFO=0
MSG_ERROR=1

# Function display version smbc.
function smbc_version {
    echo -e "c2NibSB2ZXJzaW9uIDEuMCwgU3luY2hyb25pemUgTWluSU8gYnVja2V0cyBjb250ZW50ClJlbGVhc2UgZGF0ZSA6IFN1biAyNSBKdW4gMjAyMyAxMTozODoyOCBBTSArMDcKQ29weXJpZ2h0IChDKSAyMDIzIFVOTwpMaWNlbnNlIEdQTHYzKzogR05VIEdQTCB2ZXJzaW9uIDMgb3IgbGF0ZXIgPGh0dHBzOi8vZ251Lm9yZy9saWNlbnNlcy9ncGwuaHRtbD4uClRoaXMgaXMgZnJlZSBzb2Z0d2FyZTogeW91IGFyZSBmcmVlIHRvIGNoYW5nZSBhbmQgcmVkaXN0cmlidXRlIGl0LgpUaGVyZSBpcyBOTyBXQVJSQU5UWSwgdG8gdGhlIGV4dGVudCBwZXJtaXR0ZWQgYnkgbGF3LgoKV3JpdHRlbiBieSBOZ3V5ZW4gVGhhbmggUGh1b25nIChwaHVvbmd1bm9Ab3V0bG9vay5jb20pLgo=" | base64 --decode --ignore-garbage
}

# Function display help smcb.
function smbc_help {
    echo -e "U3luY2hyb25pemUgYnVja2V0cyBjb250ZW50IE1pbklPIGZvciBiYWNrdXAgdXNlIE1pbklPIENsaWVudAoKVXNhZ2U6IHNiY20gW09QVElPTl0uLi4gW0FSR1JVTUVOVF0uLi4KCk9QVElPTlMKICAgICAgICAtZiAgICAgICAgICAgICAgICBzcGVjaWZ5IGNvbmZpZ3VyYXRpb24gZmlsZSwgZGVmYXVsdCBpcyAvZXRjL3NtYmMvc21iYy5jb25mCiAgICAgICAgLWMgc3luY3x0ZXN0ICAgICAgc3luYy1wZXJmb3JtIHN5bmNocm9uaXplIGpvYiwgdGVzdC1wZXJmb3JtIHRlc3Qgam9iCiAgICAgICAgLXYgICAgICAgICAgICAgICAgb3V0cHV0IHZlcnNpb24gaW5mb3JtYXRpb24gYW5kIGV4aXQKICAgICAgICAtaCAgICAgICAgICAgICAgICBkaXNwbGF5IHRoaXMgaGVscCBhbmQgZXhpdAo=" | base64 --decode --ignore-garbage
}

# Function verify configuration path.
function verify_config_path {
    if [ -f "${CONFIG_PATH}" ] && [ -r "${CONFIG_PATH}" ] && [ -w "${CONFIG_PATH}" ] && [[ "${CONFIG_PATH}" =~ .+\.conf ]]; then
        # Exit status: Success.
        return 0
    elif [ -d "${CONFIG_PATH}" ] && [ -r "${CONFIG_PATH}" ] && [ -w "${CONFIG_PATH}" ]; then
        if [[ -z $(find "${CONFIG_PATH}" -maxdepth 1 -type f -regex ".+\.conf" 2>&1) ]]; then
            RETMSG="${0}: No configuration found in ${CONFIG_PATH}."
            # Exit status: No such file or directory.
            return 2
        fi
        # Exit status: Success.
        return 0
    fi
    RETMSG="${0}: Cannot access ${CONFIG_PATH}. The path is invalid or the user \`$(whoami)\` is running without permission."
    # Exit status: Permission denied.
    return 13
}

# Function verify alias is exist and valid.
function verify_mcalias {
    COUNT=0
    COMMAND="mc alias list ${ALIAS}"
    while read -r ELEMENT; do
        KEY=$(echo -e "${ELEMENT}" | tr -s '[:blank:]' | cut -d ' ' -f 1)
        VALUE=$(echo -e "${ELEMENT}" | tr -s '[:blank:]' | cut -d ' ' -f 3)
        case "${KEY}" in
        ${ALIAS}) ;;
        URL)
            if [[ $(echo -e "${URL}" | sed -e 's|^[^/]*//||' -e 's|/.*$||') == $(echo -e "${VALUE}" | sed -e 's|^[^/]*//||' -e 's|/.*$||') ]]; then
                COUNT=$((${COUNT} + 1))
            fi
            ;;
        AccessKey)
            if [[ "${VALUE}" == "${ACCESSKEY}" ]]; then
                COUNT=$((${COUNT} + 1))
            fi
            ;;
        SecretKey)
            if [[ "${VALUE}" == "${SECRETKEY}" ]]; then
                COUNT=$((${COUNT} + 1))
            fi
            ;;
        esac
    done <<<$(bash -c "${COMMAND} 2>&1")
    if [ "${COUNT}" -eq 3 ]; then
        # Exit status: Success.
        return 0
    fi
    # Exit status: Invalid argument.
    return 22
}

# Set or update MinIO deployment Alias.
function set_mcalias {
    # Inorge if Alias is exist.
    if verify_mcalias; then
        # Exit status: Success.
        return 0
    fi
    # Set new Alias.
    COMMAND="mc alias set ${ALIAS} ${URL} ${ACCESSKEY} ${SECRETKEY}"
    while read -r ELEMENT; do
        if [[ "${ELEMENT}" =~ Added.+successfully.* ]]; then
            # Exit status: Success.
            return 0
        fi
    done <<<$(bash -c "${COMMAND}" 2>&1)
    RETMSG="${0}: Set MinIO alias ${ALIAS} failed."
    # Exit status: Function not implemented.
    return 38
}

# Perform a ping test to MinIO deployment.
function perform_ping_test {
    if ! set_mcalias; then
        # Exit status: Operation not permitted.
        return 1
    fi
    COUNT=0
    COMMAND="mc ping ${ALIAS} --count 5"
    while read -r ELEMENT; do
        if ! [[ "${ELEMENT}" =~ errors=0 ]]; then
            COUNT=$((COUNT + 1))
        fi
    done <<<$(bash -c "${COMMAND}" 2>&1)
    if [ "${COUNT}" -eq 5 ]; then
        RETMSG="${0}: MinIO Client cannot connect to ${URL}."
        # Exit status: Transport endpoint is not connected
        return 107
    elif [ "${COUNT}" -gt 2 ]; then
        # Re-test
        perform_ping_test
    fi
    # Exit status: Success.
    return 0
}

# Function check the configuration synchronization.
function smbc_validate {
    # Check configuration file is readable
    if ! [ -f "${1}" ] && [ -r "${1}" ] && [ -w "${1}" ]; then
        RETMSG="${0}: Cannot access ${1}. The path is invalid or the user \`$(whoami)\` is running without permission."
        # Exit status: Permission denied.
        return 13
    fi
    # Load configuration argruments.
    if ! source "${1}" >/dev/null 2>&1; then
        RETMSG="${0}: Load configuration from ${1} failed."
        # Exit status: Operation not permitted.
        return 1
    fi
    # Perform ping test to MinIO deployment.
    if ! perform_ping_test; then
        # Exit status: Operation not permitted.
        return 1
    fi
    # Check backup directory.
    if ! [ -d "${BACKUP_DIR}" ] && [ -r "${BACKUP_DIR}" ] && [ -w "${BACKUP_DIR}" ]; then
        RETMSG="${0}: Cannot access ${BACKUP_DIR}. The path is invalid or the user \`$(whoami)\` is running without permission."
        # Exit status: Permission denied.
        return 13
    fi
    # Test success. End.
    RETMSG="All configurations test successfully!"
    # Exit status: Success.
    return 0
}

# Function send message to Telegram. ${1}-Message to send, ${2}-Message flag.
function send_message_telegram {
    MESSAGE="\u24c2\ufe0f *Synchronize MinIO buckets content* \u24c2\ufe0f\n\u2747\ufe0f _Version ${VERSION}\_\n\n\n"
    if [ "${2}" == 0 ]; then
        MESSAGE+="${1}"
        MESSAGE+="\n\u2705\u2705\u2705"
    else
        MESSAGE+="${1}"
        MESSAGE+="\n\u274c\u274c\u274c"
    fi
    URL="https://api.telegram.org/bot${TELEBOT_TOKEN}/sendMessage"
    HEADER1="accept: application/json"
    HEADER2="content-type: application/json"
    DATA="{\"text\": \"${MESSAGE}\",\"parse_mode\": \"Markdown\",\"disable_web_page_preview\": false,\"disable_notification\": false,\"reply_to_message_id\": null,\"chat_id\": \"${TELECHAT_ID}\"}"
    COMMAND="curl --request POST --url '${URL}' --header '${HEADER1}' --header '${HEADER2}' --data '${DATA}'"
    bash -c "${COMMAND}" >/dev/null 2>&1
}

# Function synchronize MinIO bucket.
function smbc_sync {
    # Load configuration arguments.
    if ! source "${1}" >/dev/null 2>&1; then
        RETMSG="${0}: Load configuration from ${1} failed."
        # Exit status: Operation not permitted.
        return 1
    fi
    # Check MinIO buckets.
    if [ -z "${BUCKETS_SOURCE}" ]; then
        COMMAND="mc ls ${ALIAS}"
        while read -r ARG; do
            BUCKET=$(echo -e "${ARG}" | tr -s '[:blank:]' | cut -d ' ' -f 5 | cut -d '/' -f 1)
            BUCKETS_SOURCE="${BUCKETS_SOURCE},${BUCKET}"
        done <<<$(bash -c "${COMMAND}" 2>&1)
    fi
    BUCKETS_SOURCE=$(echo -e "${BUCKETS_SOURCE}" | tr -s ',' | sed 's/,*$|^,*//g') | sed 's/^,*//g'
    if ! [ -z "${BUCKETS_SOURCE}" ]; then
        RETMSG="From MinIO deployment ${URL}:"
        COMMAND="mc mirror --overwrite"
        if [[ "${LIMIT_DOWNLOAD}" =~ [0-9]+(B|K|G|T|Ki|Gi|Ti) ]]; then
            COMMAND="${COMMAND} --limit-download ${LIMIT_DOWNLOAD}"
        fi
        IFS=',' read -a ARR <<<${BUCKETS_SOURCE}
        for BUCKET in ${ARR[@]}; do
            EXCUTE="${COMMAND} ${ALIAS}/${BUCKET} ${BACKUP_DIR}/${BUCKET}"
            if bash -c "${EXCUTE} >/dev/null 2>&1"; then
                RETMSG="${RETMSG}\n...Synchronize \`${BUCKET}\` successful."
            else
                RETMSG="${RETMSG}\n...Synchronize \`${BUCKET}\` failed."
            fi
        done
    else
        RETMSG="No bucket found on ${URL}."
    fi
    # Exit status: Success.
    return 0
}

# Check log file exists and roltates if larger than 50 MB (52428800 bytes).
if ! [ -e "${LOG_FILE}" ]; then
    touch "${LOG_FILE}"
elif [ -f "${LOG_FILE}" ] && [ -r "${LOG_FILE}" ] && [ -w "${LOG_FILE}" ]; then
    TOTAL_SIZE=$(stat --format=%s "${LOG_FILE}")
    if [ "${TOTAL_SIZE}" -gt 52428800 ]; then
        mv "${LOG_FILE}" "${LOG_FILE}"-$(date +"%Y%m%d%H%M%S").log
        touch "${LOG_FILE}"
    fi
else
    MESSAGE="${0}: An error occurred with ${LOG_FILE}. Synchronization has not been performed!"
    echo -e "${MESSAGE}"
    # Wite to error log file.
    printf "\n%-22b%b\n" "${TIMESTAMP}" "${MESSAGE}" >>"${ERROR_LOG_FILE}"
    # Exit status: Operation not permitted.
    exit 1
fi

# Check MinIO Client is installed.
if ! type mc >/dev/null 2>&1; then
    MESSAGE="${0}: MinIO client is required for ${0}, but it is not installed. Process has been aborted!"
    echo -e "${MESSAGE}"
    # Wite log to error log file.
    printf "\n%-22s%s" "${TIMESTAMP}" "${MESSAGE}" >>"${ERROR_LOG_FILE}"
    # Exit status: Operation not permitted.
    exit 1
fi

# Parse usage command.
OPTIONS_SRING=":f:c:vh"
while getopts "${OPTIONS_SRING}" OPTION; do
    case ${OPTION} in
    c)
        COMMAND=${OPTARG}
        ;;
    f)
        # Resolve absolute path.
        if [[ "${OPTARG}" =~ ^/ ]]; then
            CONFIG_PATH=${OPTARG}
        elif [[ "${OPTARG}" =~ ^~ ]]; then
            CONFIG_PATH="${HOME}$(echo -e ${OPTARG} | sed 's/^~//g')"
        else
            CONFIG_PATH="$(realpath $(dirname "${OPTARG}"))/$(basename "${OPTARG}")"
        fi
        ;;
    v)
        smbc_version
        # Exit status: Success.
        exit 0
        ;;
    h)
        smbc_help
        # Exit status: Success.
        exit 0
        ;;
    :)
        printf "%s\n%s\n" "${0}: An argument must be provided for -'${OPTARG}'" "Try '${0} -h' for more information."
        # Exit status: Operation not permitted.
        exit 1
        ;;
    ?)
        printf "%s\n%s\n" "${0}: Invalid command -'${OPTARG}'" "Try '${0} -h' for more information."
        # Exit status: Operation not permitted.
        exit 1
        ;;
    esac
done

## Processing

# Parsing command. t-Perform test configuration, c-Perform synchronization.
if [[ "${COMMAND}" =~ t|(tT|eE|sS|tT) ]]; then
    # Display banner.
    echo -e "PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQogIFNZTkNIUk9OSVpFIE1JTklPIEJVQ0tFVFMgQ09OVEVOVAogICAgICAgICAgICBWZXJzaW9uIDEuMC4wCiAgICBQb3dlcmVkIGJ5IE5ndXllbiBUaGFuaCBQaHVvbmcKPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQo=" | base64 --decode --ignore-garbage
    printf "\n"
    # Verify configuration files exist and are readable.
    if ! verify_config_path; then
        echo -e "${RETMSG}"
        # Wite to log file.
        printf "\n%-22b%b\n" "${TIMESTAMP}" "${RETMSG}" >>"${LOG_FILE}"
        # Exit status: Operation not permitted.
        return 1
    fi
    while read -r ELEMENT; do
        smbc_validate "${ELEMENT}"
        echo -e "${RETMSG}"
        # Wite to log file.
        printf "\n%-22b%b\n" "${TIMESTAMP}" "${RETMSG}" >>"${LOG_FILE}"
    done <<<$(find "${CONFIG_PATH}" -maxdepth 1 -type f -regex ".+\.conf" 2>&1)
    # Exit status: Success.
    exit 0
elif [[ "${COMMAND}" =~ s|(sS|yY|nN|cC) ]]; then
    # Display banner.
    echo -e "PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQogIFNZTkNIUk9OSVpFIE1JTklPIEJVQ0tFVFMgQ09OVEVOVAogICAgICAgICAgICBWZXJzaW9uIDEuMC4wCiAgICBQb3dlcmVkIGJ5IE5ndXllbiBUaGFuaCBQaHVvbmcKPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQo=" | base64 --decode --ignore-garbage
    printf "\n"
    # Verify configuration files exist and are readable.
    if ! verify_config_path; then
        echo -e "${RETMSG}"
        # Wite to log file.
        printf "\n%-22b%b\n" "${TIMESTAMP}" "${RETMSG}" >>"${LOG_FILE}"
        # Send message to Telegram
        send_message_telegram "${RETMSG}" "${MSG_ERROR}" >/dev/null 2>&1
        # Exit status: Operation not permitted.
        return 1
    fi
    while read -r CONF; do
        if ! smbc_validate "${CONF}"; then
            echo -e "${RETMSG}"
            # Wite to log file.
            printf "\n%-22b%b\n" "${TIMESTAMP}" "${RETMSG}" >>"${LOG_FILE}"
            # Send message to Telegram
            send_message_telegram "${RETMSG}" "${MSG_ERROR}" >/dev/null 2>&1
            # Exit status: Operation not permitted.
            exit 1
        fi
        if smbc_sync "${CONF}"; then
            echo -e "${RETMSG}"
            # Wite to error log file.
            printf "\n%-22b%b\n" "${TIMESTAMP}" "${RETMSG}" >>"${LOG_FILE}"
            # Send message to Telegram
            send_message_telegram "${RETMSG}" "${MSG_INFO}" >/dev/null 2>&1
        else
            echo -e "${RETMSG}"
            # Wite to error log file.
            printf "\n%-22b%b\n" "${TIMESTAMP}" "${RETMSG}" >>"${LOG_FILE}"
            # Send message to Telegram
            send_message_telegram "${RETMSG}" "${MSG_ERROR}" >/dev/null 2>&1
        fi
    done <<<$(find "${CONFIG_PATH}" -maxdepth 1 -type f -regex ".+\.conf" 2>&1)
    # Exit status: Success.
    exit 0
fi
