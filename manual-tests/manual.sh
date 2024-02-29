#!/bin/bash
#
# script to check OpenPGP Application features
#

exeName=$(readlink "$0")
[[ -z ${exeName} ]] && exeName=$0
dirName=$(dirname "${exeName}")

gnupg_home_dir="$(realpath "${dirName}/gnupg")"

VERBOSE=false
EXPERT=false

#===============================================================================
#
#     help - Prints script help and usage
#
#===============================================================================
# shellcheck disable=SC2154  # var is referenced but not assigned
help() {
  echo
  echo "Usage: ${exeName} <options>"
  echo
  echo "Options:"
  echo
  echo "  -c <init|reset|card|encrypt|decryptsign|verify>  : Requested command"
  echo "  -e     : Expert mode mode"
  echo "  -v     : Verbose mode"
  echo "  -h     : Displays this help"
  echo
  exit 1
}

#===============================================================================
#
#     reset - Kill running process, ensure clear next operation
#
#===============================================================================
reset() {
  # Kill running process
  killall scdaemon gpg-agent 2>/dev/null
}

#===============================================================================
#
#     init - Init the gnupg config, start from an empty keyring
#
#===============================================================================
init() {
  reset

  # Cleanup old gnupg home directory
  dir=$(basename "${gnupg_home_dir}")
  rm -fr "${dir}" foo.txt*
  mkdir "${dir}"
  chmod 700 "${dir}"

  {
    echo reader-port \"Ledger token\"
    echo allow-admin
    echo enable-pinpad-varlen
    echo card-timeout 1
  } > "${dir}/scdaemon.conf"
}

#===============================================================================
#
#     card - Show/edit the card status and configuration
#
#===============================================================================
card() {
  local expert_mode=""

  [[ ${EXPERT} == true ]] && expert_mode="--expert"

  gpg --homedir "${gnupg_home_dir}" ${expert_mode} --card-edit
}

#===============================================================================
#
#     encrypt - Encrypt a clear file
#
#===============================================================================
encrypt() {
  local recipient=""
  local verbose_mode=""
  reset
  rm -fr foo*
  echo CLEAR > foo.txt

  [[ ${VERBOSE} == true ]] && verbose_mode="--verbose"

  recipient=$(gpg --homedir "${gnupg_home_dir}" --card-status  | grep "General key info" | awk  '{print $NF}')

  echo "Encrypt with recipient '${recipient}'"

  gpg --homedir "${gnupg_home_dir}" ${verbose_mode} --encrypt --recipient "${recipient}" foo.txt
}

#===============================================================================
#
#     decrypt - Decrypt a file and compare with original clear content
#
#===============================================================================
decrypt() {
  local verbose_mode=""

  reset

  [[ ${VERBOSE} == true ]] && verbose_mode="--verbose"

  gpg --homedir "${gnupg_home_dir}" ${verbose_mode} --decrypt foo.txt.gpg > foo_dec.txt

  # Check with original clear file
  diff foo.txt foo_dec.txt >/dev/null
  if [[ $? -eq 0 ]]; then
    echo "Success !"
  else
    echo "Decryption error!"
  fi
  rm -fr foo*
}

#===============================================================================
#
#     sign - Sign a file
#
#===============================================================================
sign() {
  local verbose_mode=""

  reset
  rm -fr foo*
  echo CLEAR > foo.txt

  [[ ${VERBOSE} == true ]] && verbose_mode="--verbose"

  gpg --homedir "${gnupg_home_dir}" ${verbose_mode} --sign foo.txt
}

#===============================================================================
#
#     verify - Verify a file signature
#
#===============================================================================
verify() {
  local verbose_mode=""

  reset

  [[ ${VERBOSE} == true ]] && verbose_mode="--verbose"

  gpg --homedir "${gnupg_home_dir}" ${verbose_mode} --verify foo.txt.gpg
  rm -fr foo*
}

#===============================================================================
#
#     Parsing parameters
#
#===============================================================================

if (($# < 1)); then
  help
fi

while getopts ":c:evh" opt; do
  case $opt in

    c)
      case ${OPTARG} in
        init|reset|card|encrypt|decrypt|sign|verify)
          CMD=${OPTARG}
          ;;
        *)
          echo "Wrong parameter '${OPTARG}'!"
          exit 1
          ;;
      esac
      ;;

    e)  EXPERT=true ;;
    v)  VERBOSE=true ;;
    h)  help ;;

    \?) echo "Unknown option: -${OPTARG}" >&2; exit 1;;
    : ) echo "Missing option argument for -${OPTARG}" >&2; exit 1;;
    * ) echo "Unimplemented option: -${OPTARG}" >&2; exit 1;;
  esac
done

#===============================================================================
#
#     Main
#
#===============================================================================

# execute the command
${CMD}
