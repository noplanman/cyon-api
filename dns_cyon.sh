#!/usr/bin/env sh

########
# Custom cyon.ch DNS API for use with [acme.sh](https://github.com/Neilpang/acme.sh)
#
# Usage: acme.sh --issue --dns dns_cyon -d www.domain.com
#
# Installation:
# -------------
# 1. Install acme.sh (https://github.com/Neilpang/acme.sh#1-how-to-install)
# 2. Move this script to "~/.acme.me/dnsapi/dns_cyon.sh"
# 3. Enter your cyon.ch login credentials below (or export as environment variables)
# 4. Execute acme.sh using the "--dns dns_cyon" parameter
# 5. Awesomeness!
#
# *Note:*
# jq is required too, get it here: https://stedolan.github.io/jq/download/
#
# Author: Armando Lüscher <armando@noplanman.ch>
########

########
# Define cyon.ch login credentials:
#
# Either set them here: (uncomment these lines)
#
# cyon_username='your_cyon_username'
# cyon_password='your_cyon_password'
#
# ...or export them as environment variables in your shell:
#
# $ export cyon_username='your_cyon_username'
# $ export cyon_password='your_cyon_password'
#
# *Note:*
# After the first run, the credentials are saved in the "account.conf"
# file, so any hard-coded or environment variables can then be removed.
########

dns_cyon_add() {
  _load_credentials

  # Read the required parameters to add the TXT entry.
  fulldomain=$1
  txtvalue=$2

  # Cookiejar required for login session, as cyon.ch has no official API (yet).
  cookiejar=$(tempfile)

  _info_header
  _login
  _addtxt
  _cleanup

  return 0;
}

_load_credentials() {
  # Convert loaded password to/from base64 as needed.
  if [ "${cyon_password_b64}" ] ; then
    cyon_password="$(echo ${cyon_password_b64} | _dbase64)"
  elif [ "${cyon_password}" ] ; then
    cyon_password_b64="$(echo ${cyon_password} | _base64)"
  fi

  if [ -z "${cyon_username}" ] || [ -z "${cyon_password}" ] ; then
    _err ""
    _err "You haven't set your cyon.ch login credentials yet."
    _err "Please set the \$cyon_username and \$cyon_password variables."
    _err ""
    exit 1
  fi

  # Save the login credentials to the account.conf file.
  _debug "Save credentials to account.conf"
  _saveaccountconf cyon_username "${cyon_username}"
  _saveaccountconf cyon_password_b64 "$cyon_password_b64"
}

_info_header() {
  _debug fulldomain "$fulldomain"
  _debug txtvalue "$txtvalue"
  _debug cookiejar "$cookiejar"

  _info ""
  _info "+---------------------------------------------+"
  _info "| Adding DNS TXT entry to your cyon.ch domain |"
  _info "+---------------------------------------------+"
  _info ""
  _info "  * Full Domain: ${fulldomain}"
  _info "  * TXT Value:   ${txtvalue}"
  _info "  * Cookie Jar:  ${cookiejar}"
  _info ""
}

_login() {
  _info "  - Logging in..."
  login_response=$(curl "https://my.cyon.ch/auth/index/dologin-async" \
    -s \
    -c "${cookiejar}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "x-requested-with: XMLHttpRequest" \
    --data-urlencode "username=${cyon_username}" \
    --data-urlencode "password=${cyon_password}" \
    --data-urlencode "pathname=/")

  _debug login_response "${login_response}"

  login_success=$(echo "${login_response}" | jq -r '.onSuccess')
  _info "    ${login_success}"

  # Bail if login fails.
  if [ "${login_success}" != "success" ]; then
    _fail "    $(echo "${login_response}" | jq -r '.message')"
  fi

  _info ""
}

_addtxt() {
  _info "  - Adding DNS TXT entry..."
  addtxt_response=$(curl "https://my.cyon.ch/domain/dnseditor/add-record-async" \
    --compressed \
    -s \
    -b "${cookiejar}" \
    -H "Accept: */*" \
    -H "Referer: https://my.cyon.ch/domain/dnseditor" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "x-requested-with: XMLHttpRequest" \
    -d "type=TXT&ttl=900&zone=${fulldomain}.&value=${txtvalue}")

  _debug addtxt_response "${addtxt_response}"

  addtxt_message=$(echo "${addtxt_response}" | jq -r '.message')
  addtxt_status=$(echo "${addtxt_response}" | jq -r '.status')

  # Bail if adding TXT entry fails.
  if [ "${addtxt_status}" != "true" ]; then
    if [ "${addtxt_status}" = "null" ]; then
      addtxt_message=$(echo "${addtxt_response}" | jq -r '.error.message')
    fi
    _fail "    ${addtxt_message}"
  fi

  _info "    ${addtxt_message}"
  _info ""
}

_fail() {
  _err "$1"
  _err ""
  _cleanup
  exit 1
}

_cleanup() {
  _debug "Remove cookie jar: ${cookiejar}"
  rm "${cookiejar}"
  _info "  - Cleanup."
  _info ""
}