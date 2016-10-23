#!/usr/bin/env sh

########
# Custom cyon.ch DNS API for use with acme.sh (https://github.com/Neilpang/acme.sh)
#
# Usage: acme.sh --issue --dns dns_cyon -d www.domain.com
#
# Installation:
# -------------
# 1. Install acme.sh (https://github.com/Neilpang/acme.sh#1-how-to-install)
# 2. Move this script to "~/.acme.me/dnsapi/dns_cyon.sh"
# 3. Enter your cyon.ch login credentials (as explained below)
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
# Either set them here or in the "account.conf" file: (uncomment these lines)
#
# cyon_username='your_cyon_username'
# cyon_password='your_cyon_password'
#
# ...or export them as environment variables in your shell:
#
# $ export cyon_username='your_cyon_username'
# $ export cyon_password='your_cyon_password'
#
########

dns_cyon_add() {
  if [ -z "$cyon_username" ] || [ -z "$cyon_password" ] ; then
    _err "You haven't set your cyon.ch login credentials yet."
    _err "Please set the \$cyon_username and \$cyon_password variables."
    return 1
  fi

  # Save the login credentials to the account.conf file.
  _saveaccountconf cyon_username "${cyon_username}"
  _saveaccountconf cyon_password "${cyon_password}"

  # Read the required parameters to add the TXT entry.
  fulldomain=$1
  txtvalue=$2

  # Cookiejar required for login session, as cyon.ch has no official API (yet).
  cookiejar=$(tempfile)

  echo
  echo "+---------------------------------------------+"
  echo "| Adding DNS TXT entry to your cyon.ch domain |"
  echo "+---------------------------------------------+"
  echo
  echo "  * Full Domain: ${fulldomain}"
  echo "  * TXT Value:   ${txtvalue}"
  echo "  * Cookie Jar:  ${cookiejar}"
  echo

  printf "  - Logging in... "
  curl "https://my.cyon.ch/auth/index/dologin-async" -s \
  -c "${cookiejar}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "x-requested-with: XMLHttpRequest" \
  --data-urlencode "username=${cyon_username}" --data-urlencode "password=${cyon_password}" --data-urlencode "pathname=/" \
  | jq -r '.onSuccess'

  printf "  - Adding DNS TXT entry... "
  curl "https://my.cyon.ch/domain/dnseditor/add-record-async" -s \
  -b "${cookiejar}" \
  -H "Accept: */*" \
  --compressed \
  -H "Referer: https://my.cyon.ch/domain/dnseditor" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "x-requested-with: XMLHttpRequest" \
  -d "zone=${fulldomain}.&ttl=900&type=TXT&value=${txtvalue}" \
  | jq -r '.message'

  echo

  rm ${cookiejar}

  return 0;
}
