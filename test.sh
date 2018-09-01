#!/bin/sh

# "Defensive BASH programming"
# https://news.ycombinator.com/item?id=10736584

# "Use the Unofficial Bash Strict Mode (Unless You Looove Debugging)"
# http://redsymbol.net/articles/unofficial-bash-strict-mode/

# "How to recognize whether bash or dash is being used within a script?"
# https://stackoverflow.com/questions/23011370/how-to-recognize-whether-bash-or-dash-is-being-used-within-a-script

# "How does the leading dollar sign affect single quotes in Bash?"
# https://stackoverflow.com/questions/11966312/how-does-the-leading-dollar-sign-affect-single-quotes-in-bash

set -o errexit -o nounset

# The recommendation is to set IFS=$'\n\t', but the following works in Bash and
# Dash.
IFS="$(printf '\n\t' '')"

if [ -n "${BASH_VERSION:-}" ]; then
  # set -o pipefail fails on Debian 9.5 and Ubuntu 18.04, which use dash by
  # default.
  set -o pipefail
fi

assert_equals() {
  local expected="$1"
  local actual="${2}"

  # Modify ps aux output to get consistent output.
  # nonroot      1  4.0  0.1  49588  3116 pts/0    Rs+  00:00   00:00 ps aux
  local integer='[0-9][0-9]*'
  local whitespace='[[:blank:]][[:blank:]]*'
  local float='[0-9][0-9]*\.[0-9][0-9]*'
  local time='[0-9][0-9]*:[0-9][0-9]*'
  actual=`print_s "${actual}" | sed -e "s/\(${integer}\)${whitespace}${float}${whitespace}${float}${whitespace}${integer}${whitespace}${integer}/\1/g"`
  actual=`print_s "${actual}" | sed -e "s/${time}${whitespace}${time}//g"`

  actual="`remove_control_characters "${actual}"`"

  actual=`print_s "${actual}" | sed -e "s/\(ps aux${whitespace}\)${integer}/\12/g"`
  actual=`print_s "${actual}" | sed -e "s/\(ps aux[a-z][a-z]*\)${whitespace}${integer}/\1 2/g"`

  if printf '%s' "${expected}" | grep -q '^\*USE_GREP\*'; then
    local expected_substring="$(printf '%s' "${expected}" | sed -E 's/\*USE_GREP\* (.*)/\1/')"
    if ! printf '%s' "${actual}" | grep -Fq "${expected_substring}"; then
      print_sn "$(output_red)ERROR: We expected \"$(output_bold)${expected_substring}$(output_reset)$(output_red)\" to appear in \"$(output_bold)${actual}\"$(output_reset)"
      exit 1
    fi
    return 0
  fi

  if [ "${expected}" != "${actual}" ]; then
    print_sn "$(output_red)ERROR: We expected \"$(output_bold)${expected}$(output_reset)$(output_red)\" but got \"$(output_bold)${actual}\"$(output_reset)"
    exit 1
  fi
}

local_tput () {
  # "No value for $TERM and no -T specified"
  # https://askubuntu.com/questions/591937/no-value-for-term-and-no-t-specified
  tty -s > /dev/null 2>&1
  if [ ! "$?" -eq 0 ]; then
    return 0
  fi
  command -v tput > /dev/null 2>&1
  if [ "$?" -eq 0 ]; then
    # $@ is unquoted.
    tput $@
  fi
}

output_bold () {
  local_tput bold
}

output_cyan () {
  local_tput setaf 6
}

output_green () {
  local_tput setaf 2
}

output_red () {
  local_tput setaf 1
}

output_reset () {
  local_tput sgr0
}

print_nsn () {
  printf '\n%s\n' "${1}"
}

print_nsnn () {
  printf '\n%s\n\n' "${1}"
}

print_s () {
  printf '%s' "${1}"
}

print_sn () {
  printf '%s\n' "${1}"
}

print_snn () {
  printf '%s\n\n' "${1}"
}

print_test_header () {
  local message="$1"
  print_nsnn "$(output_green)$(output_bold)${message}$(output_reset)"
}

remove_control_characters () {
  local string="$1"
  print_s "${string}" | tr -d '[:cntrl:]' | sed -e 's/%//g'
}

test () {
  # "How create a temporary file in shell script?"
  # https://unix.stackexchange.com/questions/181937/how-create-a-temporary-file-in-shell-script
  tmpfile="$(mktemp)"
  exec 3> "${tmpfile}"
  exec 4< "${tmpfile}"
  rm "${tmpfile}"

  test_image 'alpine:3.8' 'run-non-root -- ps aux' 'alpine'
  test_image 'centos:7' 'run-non-root -- ps aux' 'centos'
  test_image 'debian:9.5' 'sh -c "apt-get update && apt-get install -y procps && run-non-root ps aux"' 'debian'
  test_image 'fedora:28' 'sh -c "dnf install -y procps-ng && run-non-root ps aux"' 'fedora'
  test_image 'ubuntu:18.04' 'run-non-root -- ps aux' 'ubuntu'

  # Test check_for_getopt since CentOS 6 does not have getopt by default.
  test_bare_image 'centos:6' 'run-non-root -- ps aux'
}

test_bare_image () {
  local image="$1"
  local command="$2"

  print_test_header 'Test bare image.'

  local docker_command="$(
    print_s 'docker run'
    print_s ' -it'
    print_s ' --rm'
    print_s " --volume $(pwd)/run-non-root.sh:/usr/local/bin/run-non-root:ro"
    print_s " ${image}"
    print_s " ${command}"
  )"
  print_sn "$(output_green)Testing $(output_cyan)${docker_command}$(output_reset)$(output_green) ... $(output_reset)"
  eval "${docker_command}"

  command="$(print_s "${command}" | sed -e 's/run-non-root/run-non-root -i/g')"
  docker_command="$(
    print_s 'docker run'
    print_s ' -it'
    print_s ' --rm'
    print_s ' --volume $(pwd)/run-non-root.sh:/usr/local/bin/run-non-root:ro'
    print_s " ${image}"
    print_s " ${command}"
  )"
  print_nsn "$(output_green)Testing $(output_cyan)${docker_command}$(output_reset)$(output_green) ... $(output_reset)"
  eval "$docker_command"
}

test_image () {
  local bare_image="$1"
  local bare_image_command="$2"
  local os="$3"

  local mail_gid=''
  local daemon_gid=''
  case "${os}" in
    alpine|centos|fedora)
      mail_gid=12
      daemon_gid=2
      break
      ;;
    debian|ubuntu)
      mail_gid=8
      daemon_gid=1
      break
      ;;
    *)
      print_sn "$(output_red)ERROR: We encountered an unexpected case ${case}.$(output_reset)"
      exit 1
      ;;
  esac

  local mail_gid_uid=''
  local twelve_group_uid=''
  local twelve_group_name=''
  case "${os}" in
    alpine)
      mail_gid_uid=12
      twelve_group_uid=12
      twelve_group_name='mail'
      break
      ;;
    centos|fedora)
      mail_gid_uid=1000
      twelve_group_uid=1000
      twelve_group_name='mail'
      break
      ;;
    debian|ubuntu)
      mail_gid_uid=1000
      twelve_group_uid=12
      twelve_group_name='man'
      break
      ;;
    *)
      print_sn "$(output_red)ERROR: We encountered an unexpected case ${case}.$(output_reset)"
      exit 1
      ;;
  esac

  local before_error=''
  local after_error=''
  local before_warning=''
  local after_warning=''
  local reset=''
  case "${os}" in
    alpine|fedora)
      break
      ;;
    centos|debian|ubuntu)
      before_error='[31m[1m'
      after_error='(B[m[31m'
      before_warning='[33m[1m'
      after_warning='(B[m[33m'
      reset='(B[m'
      break
      ;;
    *)
      print_sn "$(output_red)ERROR: We encountered an unexpected case ${case}.$(output_reset)"
      exit 1
      ;;
  esac

  print_test_header 'No option exists.'

  test_options \
    'uid=1000(nonroot) gid=1000(nonroot) groups=1000(nonroot)' \
    '-q' \
    "${os}"
  test_options \
    'uid=1234(nonroot) gid=1234(nonroot) groups=1234(nonroot)' \
    '-q -u 1234' \
    "${os}"
  test_options \
    'uid=1000(abcd) gid=1000(abcd) groups=1000(abcd)' \
    '-q -t abcd' \
    "${os}"
  test_options \
    'uid=1234(abcd) gid=1234(abcd) groups=1234(abcd)' \
    '-q -t abcd -u 1234' \
    "${os}"
  test_options \
    'uid=5678(nonroot) gid=5678(nonroot) groups=5678(nonroot)' \
    '-q -g 5678' \
    "${os}"
  test_options \
    'uid=1234(nonroot) gid=5678(nonroot) groups=5678(nonroot)' \
    '-q -g 5678 -u 1234' \
    "${os}"
  test_options \
    'uid=5678(abcd) gid=5678(abcd) groups=5678(abcd)' \
    '-q -g 5678 -t abcd' \
    "${os}"
  test_options \
    'uid=1234(abcd) gid=5678(abcd) groups=5678(abcd)' \
    '-q -g 5678 -t abcd -u 1234' \
    "${os}"
  test_options \
    'uid=1000(nonroot) gid=1000(efgh) groups=1000(efgh)' \
    '-q -f efgh' \
    "${os}"
  test_options \
    'uid=1234(nonroot) gid=1234(efgh) groups=1234(efgh)' \
    '-q -f efgh -u 1234' \
    "${os}"
  test_options \
    'uid=1000(abcd) gid=1000(efgh) groups=1000(efgh)' \
    '-q -f efgh -t abcd' \
    "${os}"
  test_options \
    'uid=1234(abcd) gid=1234(efgh) groups=1234(efgh)' \
    '-q -f efgh -t abcd -u 1234' \
    "${os}"
  test_options \
    'uid=5678(nonroot) gid=5678(efgh) groups=5678(efgh)' \
    '-q -f efgh -g 5678' \
    "${os}"
  test_options \
    'uid=1234(nonroot) gid=5678(efgh) groups=5678(efgh)' \
    '-q -f efgh -g 5678 -u 1234' \
    "${os}"
  test_options \
    'uid=5678(abcd) gid=5678(efgh) groups=5678(efgh)' \
    '-q -f efgh -g 5678 -t abcd' \
    "${os}"
  test_options \
    'uid=1234(abcd) gid=5678(efgh) groups=5678(efgh)' \
    '-q -f efgh -g 5678 -t abcd -u 1234' \
    "${os}"

  print_test_header 'User ID 8 exists.'

  test_options \
    "uid=8(mail) gid=${mail_gid}(mail) groups=${mail_gid}(mail)" \
    '-q -u 8' \
    "${os}"
  test_options \
    "uid=8(mail) gid=${mail_gid}(mail) groups=${mail_gid}(mail)" \
    '-q -t abcd -u 8' \
    "${os}"
  test_options \
    'uid=8(mail) gid=5678(nonroot) groups=5678(nonroot)' \
    '-q -g 5678 -u 8' \
    "${os}"
  test_options \
    'uid=8(mail) gid=5678(nonroot) groups=5678(nonroot)' \
    '-q -g 5678 -t abcd -u 8' \
    "${os}"
  test_options \
    'uid=8(mail) gid=1000(efgh) groups=1000(efgh)' \
    '-q -f efgh -u 8' \
    "${os}"
  test_options \
    'uid=8(mail) gid=1000(efgh) groups=1000(efgh)' \
    '-q -f efgh -t abcd -u 8' \
    "${os}"
  test_options \
    'uid=8(mail) gid=5678(efgh) groups=5678(efgh)' \
    '-q -f efgh -g 5678 -u 8' \
    "${os}"
  test_options \
    'uid=8(mail) gid=5678(efgh) groups=5678(efgh)' \
    '-q -f efgh -g 5678 -t abcd -u 8' \
    "${os}"

  print_test_header 'Username mail exists.'

  test_options \
    "uid=8(mail) gid=${mail_gid}(mail) groups=${mail_gid}(mail)" \
    '-q -t mail' \
    "${os}"
  test_options \
    'uid=1234(nonroot) gid=1234(nonroot) groups=1234(nonroot)' \
    '-q -t mail -u 1234' \
    "${os}"
  test_options \
    'uid=8(mail) gid=5678(nonroot) groups=5678(nonroot)' \
    '-q -g 5678 -t mail' \
    "${os}"
  test_options \
    'uid=1234(nonroot) gid=5678(nonroot) groups=5678(nonroot)' \
    '-q -g 5678 -t mail -u 1234' \
    "${os}"
  test_options \
    'uid=8(mail) gid=1000(efgh) groups=1000(efgh)' \
    '-q -f efgh -t mail' \
    "${os}"
  test_options \
    'uid=1234(nonroot) gid=1234(efgh) groups=1234(efgh)' \
    '-q -f efgh -t mail -u 1234' \
    "${os}"
  test_options \
    'uid=8(mail) gid=5678(efgh) groups=5678(efgh)' \
    '-q -f efgh -g 5678 -t mail' \
    "${os}"
  test_options \
    'uid=1234(nonroot) gid=5678(efgh) groups=5678(efgh)' \
    '-q -f efgh -g 5678 -t mail -u 1234' \
    "${os}"

  print_test_header 'User ID 8 and username games exist.'

  test_options \
    "uid=8(mail) gid=${mail_gid}(mail) groups=${mail_gid}(mail)" \
    '-q -t games -u 8' \
    "${os}"
  test_options \
    'uid=8(mail) gid=5678(nonroot) groups=5678(nonroot)' \
    '-q -g 5678 -t games -u 8' \
    "${os}"
  test_options \
    'uid=8(mail) gid=1000(efgh) groups=1000(efgh)' \
    '-q -f efgh -t games -u 8' \
    "${os}"
  test_options \
    'uid=8(mail) gid=5678(efgh) groups=5678(efgh)' \
    '-q -f efgh -g 5678 -t games -u 8' \
    "${os}"

  print_test_header 'GID 12 exists.'

  test_options \
    "uid=${twelve_group_uid}(nonroot) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    '-q -g 12' \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    '-q -g 12 -u 1234' \
    "${os}"
  test_options \
    "uid=${twelve_group_uid}(abcd) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    '-q -g 12 -t abcd' \
    "${os}"
  test_options \
    "uid=1234(abcd) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    '-q -g 12 -t abcd -u 1234' \
    "${os}"
  test_options \
    "uid=${twelve_group_uid}(nonroot) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    '-q -f efgh -g 12' \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    '-q -f efgh -g 12 -u 1234' \
    "${os}"
  test_options \
    "uid=${twelve_group_uid}(abcd) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    '-q -f efgh -g 12 -t abcd' \
    "${os}"
  test_options \
    "uid=1234(abcd) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    '-q -f efgh -g 12 -t abcd -u 1234' \
    "${os}"

  print_test_header 'UID 8 and GID 100 exist.'

  test_options \
    'uid=8(mail) gid=100(users) groups=100(users)' \
    '-q -g 100 -u 8' \
    "${os}"
  test_options \
    'uid=8(mail) gid=100(users) groups=100(users)' \
    '-q -g 100 -t abcd -u 8' \
    "${os}"
  test_options \
    'uid=8(mail) gid=100(users) groups=100(users)' \
    '-q -f efgh -g 100 -u 8' \
    "${os}"
  test_options \
    'uid=8(mail) gid=100(users) groups=100(users)' \
    '-q -f efgh -g 100 -t abcd -u 8' \
    "${os}"

  print_test_header 'Username mail and GID 100 exist.'

  test_options \
    'uid=8(mail) gid=100(users) groups=100(users)' \
    '-q -g 100 -t mail' \
    "${os}"
  test_options \
    'uid=1234(nonroot) gid=100(users) groups=100(users)' \
    '-q -g 100 -t mail -u 1234' \
    "${os}"
  test_options \
    'uid=8(mail) gid=100(users) groups=100(users)' \
    '-q -f efgh -g 100 -t mail' \
    "${os}"
  test_options \
    'uid=1234(nonroot) gid=100(users) groups=100(users)' \
    '-q -f efgh -g 100 -t mail -u 1234' \
    "${os}"

  print_test_header 'UID 8, username nobody, and GID 100 exist.'

  test_options \
    'uid=8(mail) gid=100(users) groups=100(users)' \
    '-q -g 100 -t nobody -u 8' \
    "${os}"
  test_options \
    'uid=8(mail) gid=100(users) groups=100(users)' \
    '-q -f efgh -g 100 -t nobody -u 8' \
    "${os}"

  print_test_header 'Group name mail exists.'

  test_options \
    "uid=${mail_gid_uid}(nonroot) gid=${mail_gid}(mail) groups=${mail_gid}(mail)" \
    '-q -f mail' \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=${mail_gid}(mail) groups=${mail_gid}(mail)" \
    '-q -f mail -u 1234' \
    "${os}"
  test_options \
    "uid=${mail_gid_uid}(abcd) gid=${mail_gid}(mail) groups=${mail_gid}(mail)" \
    '-q -f mail -t abcd' \
    "${os}"
  test_options \
    "uid=1234(abcd) gid=${mail_gid}(mail) groups=${mail_gid}(mail)" \
    '-q -f mail -t abcd -u 1234' \
    "${os}"
  test_options \
    'uid=5678(nonroot) gid=5678(nonroot) groups=5678(nonroot)' \
    '-q -f mail -g 5678' \
    "${os}"
  test_options \
    'uid=1234(nonroot) gid=5678(nonroot) groups=5678(nonroot)' \
    '-q -f mail -g 5678 -u 1234' \
    "${os}"
  test_options \
    'uid=5678(abcd) gid=5678(abcd) groups=5678(abcd)' \
    '-q -f mail -g 5678 -t abcd' \
    "${os}"
  test_options \
    'uid=1234(abcd) gid=5678(abcd) groups=5678(abcd)' \
    '-q -f mail -g 5678 -t abcd -u 1234' \
    "${os}"

  print_test_header 'User ID 8 and group name daemon exist.'

  test_options \
    "uid=8(mail) gid=${daemon_gid}(daemon) groups=${daemon_gid}(daemon)" \
    '-q -f daemon -u 8' \
    "${os}"
  test_options \
    "uid=8(mail) gid=${daemon_gid}(daemon) groups=${daemon_gid}(daemon)" \
    '-q -f daemon -t abcd -u 8' \
    "${os}"
  test_options \
    'uid=8(mail) gid=5678(nonroot) groups=5678(nonroot)' \
    '-q -f daemon -g 5678 -u 8' \
    "${os}"
  test_options \
    'uid=8(mail) gid=5678(nonroot) groups=5678(nonroot)' \
    '-q -f daemon -g 5678 -t abcd -u 8' \
    "${os}"

  print_test_header 'Username mail and group name daemon exist.'

  test_options \
    "uid=8(mail) gid=${daemon_gid}(daemon) groups=${daemon_gid}(daemon)" \
    '-q -f daemon -t mail' \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=${daemon_gid}(daemon) groups=${daemon_gid}(daemon)" \
    '-q -f daemon -t mail -u 1234' \
    "${os}"
  test_options \
    'uid=8(mail) gid=5678(nonroot) groups=5678(nonroot)' \
    '-q -f daemon -g 5678 -t mail' \
    "${os}"
  test_options \
    'uid=1234(nonroot) gid=5678(nonroot) groups=5678(nonroot)' \
    '-q -f daemon -g 5678 -t mail -u 1234' \
    "${os}"

  print_test_header 'User ID 8, username games, and group name daemon exist.'

  test_options \
    "uid=8(mail) gid=${daemon_gid}(daemon) groups=${daemon_gid}(daemon)" \
    '-q -f daemon -t games -u 8' \
    "${os}"
  test_options \
    'uid=8(mail) gid=5678(nonroot) groups=5678(nonroot)' \
    '-q -f daemon -g 5678 -t games -u 8' \
    "${os}"

  print_test_header 'GID 12 and group name daemon exist.'

  test_options \
    "uid=${twelve_group_uid}(nonroot) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    '-q -f daemon -g 12' \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    '-q -f daemon -g 12 -u 1234' \
    "${os}"
  test_options \
    "uid=${twelve_group_uid}(abcd) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    '-q -f daemon -g 12 -t abcd' \
    "${os}"
  test_options \
    "uid=1234(abcd) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    '-q -f daemon -g 12 -t abcd -u 1234' \
    "${os}"

  print_test_header 'UID 8, GID 100, and group name daemon exist.'

  test_options \
    'uid=8(mail) gid=100(users) groups=100(users)' \
    '-q -f daemon -g 100 -u 8' \
    "${os}"
  test_options \
    'uid=8(mail) gid=100(users) groups=100(users)' \
    '-q -f daemon -g 100 -t abcd -u 8' \
    "${os}"

  print_test_header 'Username mail, GID 100, and group name daemon exist.'

  test_options \
    'uid=8(mail) gid=100(users) groups=100(users)' \
    '-q -f daemon -g 100 -t mail' \
    "${os}"
  test_options \
    'uid=1234(nonroot) gid=100(users) groups=100(users)' \
    '-q -f daemon -g 100 -t mail -u 1234' \
    "${os}"

  print_test_header 'UID 8, username nobody, GID 100, and group name daemon exist.'

  test_options \
    'uid=1234(abcd) gid=5678(efgh) groups=5678(efgh)' \
    '-q -f efgh -g 5678 -t abcd -u 1234' \
    "${os}"

  print_test_header 'Test alternative option names.'

  test_options \
    'uid=1234(abcd) gid=5678(efgh) groups=5678(efgh)' \
    '--quiet --group efgh --gid 5678 --user abcd --uid 1234' \
    "${os}"

  print_test_header 'Test environment variables.'

  test_options \
    'uid=9012(ijkl) gid=3456(mnop) groups=3456(mnop)' \
    '-q' \
    "${os}" \
    '-e RUN_NON_ROOT_GROUP=mnop -e RUN_NON_ROOT_GID=3456 -e RUN_NON_ROOT_USER=ijkl -e RUN_NON_ROOT_UID=9012'
  test_options \
    'ijkl' \
    '-q' \
    "${os}" \
    '-e RUN_NON_ROOT_COMMAND=whoami -e RUN_NON_ROOT_GROUP=mnop -e RUN_NON_ROOT_GID=3456 -e RUN_NON_ROOT_USER=ijkl -e RUN_NON_ROOT_UID=9012' \
    ' '
  test_options \
    'uid=1234(abcd) gid=5678(efgh) groups=5678(efgh)' \
    '--quiet -f efgh -g 5678 --user abcd --uid 1234' \
    "${os}" \
    '-e RUN_NON_ROOT_GROUP=mnop -e RUN_NON_ROOT_GID=3456 -e RUN_NON_ROOT_USER=ijkl -e RUN_NON_ROOT_UID=9012'

  print_test_header 'Test the --path option.'

  # Test one path.
  test_options \
    '1000 1000 ' \
    '-qp "/home/nonexistent"' \
    "${os}" \
    '' \
    "sh -c \"ls -an /home/nonexistent/ | awk -F ' ' 'FNR==2{print \\\\\\\$3\\\" \\\"\\\\\\\$4\\\" \\\"}'\""
  # Test --path.
  test_options \
    '1000 1000 ' \
    '-q --path "/home/nonexistent"' \
    "${os}" \
    '' \
    "sh -c \"ls -an /home/nonexistent/ | awk -F ' ' 'FNR==2{print \\\\\\\$3\\\" \\\"\\\\\\\$4\\\" \\\"}'\""
  # Test two paths separated by a colon.
  test_options \
    '1000 1000 ' \
    '-qp "/home/nonexistent:/home/nonexistent"' \
    "${os}" \
    '' \
    "sh -c \"ls -an /home/nonexistent/ | awk -F ' ' 'FNR==2{print \\\\\\\$3\\\" \\\"\\\\\\\$4\\\" \\\"}'\""
  # Test a different UID and GID
  test_options \
    '1234 5678 1234 5678 ' \
    '-qp "/home/nonexistent:/home/nonexistent" -p "/etc" -u 1234 -g 5678' \
    "${os}" \
    '' \
    "sh -c \"ls -an /home/nonexistent/ /etc/passwd | awk -F ' ' '((FNR==1)||(FNR==5)){print \\\\\\\$3\\\" \\\"\\\\\\\$4\\\" \\\"}'\""
  # Test tomfoolery.
  test_options \
    '1000 1000 ' \
    '-qp "/foo/bar\";echo frog"' \
    "${os}" \
    '' \
    "sh -c \"ls -an \\\"/foo/bar\\\\\\\\\\\";echo frog\\\" | awk -F ' ' 'FNR==2{print \\\\\\\$3\\\" \\\"\\\\\\\$4\\\" \\\"}'\""
  # Test directories that already have correct ownership.
  test_options \
    "*USE_GREP* ${before_warning}WARNING:${after_warning} We did not call chown on the directory ( /etc ). Its owner is already ( root:0 ).${reset}${before_warning}WARNING:${after_warning} We did not call chown on the directory ( /var ). Its owner is already ( root:0 )." \
    '-p "/etc:/var" -u 0' \
    "${os}" \
    '' \
    "true"
  test_options \
    "*USE_GREP* ${before_warning}WARNING:${after_warning} We did not call chown on the directory ( /home/nonroot ). Its owner is already ( nonroot:1000 )." \
    '-p "/home/nonroot"' \
    "${os}" \
    '' \
    "true"
  # Test an invalid path.
  case "${os}" in
    alpine)
      test_options \
        "mkdir: can't create directory '': No such file or directoryERROR (300): We could not create the directory (  )." \
        '-qp ":/home/nonexistent"' \
        "${os}"
      break
      ;;
    centos|debian|fedora|ubuntu)
      test_options \
        "mkdir: cannot create directory '': No such file or directory${before_error}ERROR (300):${after_error} We could not create the directory (  ).${reset}" \
        '-qp ":/home/nonexistent"' \
        "${os}"
      break
      ;;
    *)
      print_sn "$(output_red)ERROR: We encountered an unexpected case ${case}.$(output_reset)"
      exit 1
      ;;
  esac

  print_test_header 'Test commands with options, spaces, quotes, backlashes, and backticks.'

  test_options \
    'nonroot' \
    '-q' \
    "${os}" \
    '' \
    'id -gn'
  test_options \
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit' \
    '-q' \
    "${os}" \
    '' \
    'printf '%s' "Lorem ipsum dolor sit amet, consectetur adipiscing elit"'
  test_options \
    '"Lorem ipsum dolor sit amet, consectetur adipiscing elit"' \
    '-q' \
    "${os}" \
    '' \
    'printf "%s" "\"Lorem ipsum dolor sit amet, consectetur adipiscing elit\""'
  test_options \
    'mnop' \
    '-q' \
    "${os}" \
    '-e RUN_NON_ROOT_COMMAND="id -gn" -e RUN_NON_ROOT_GROUP=mnop -e RUN_NON_ROOT_GID=3456 -e RUN_NON_ROOT_USER=ijkl -e RUN_NON_ROOT_UID=9012' \
    ' '
  test_options \
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit' \
    '-q' \
    "${os}" \
    '-e RUN_NON_ROOT_COMMAND="printf \"%s\" \"Lorem ipsum dolor sit amet, consectetur adipiscing elit\"" -e RUN_NON_ROOT_GROUP=mnop -e RUN_NON_ROOT_GID=3456 -e RUN_NON_ROOT_USER=ijkl -e RUN_NON_ROOT_UID=9012' \
    ' '
  test_options \
    'foo bar' \
    '-q' \
    "${os}" \
    '' \
    "sh -c \"printf '%s' 'foo bar'\""
  test_options \
    'The robot said, "I am human."' \
    '-q' \
    "${os}" \
    '' \
    'printf "%s" "The robot said, \"I am human.\""'
  test_options \
    "The robot said, \"I am human.\"" \
    '-q' \
    "${os}" \
    '-e RUN_NON_ROOT_COMMAND="printf \"%s\" \"The robot said, \\\"I am human.\\\"\""' \
    ' '
  test_options \
    "The robot said, 'I am human.'" \
    '-q' \
    "${os}" \
    '' \
    "echo \"The robot said, 'I am human.'\""
  test_options \
    "The robot said, 'I am human.'" \
    '-q' \
    "${os}" \
    "-e RUN_NON_ROOT_COMMAND=\"printf \\\"%s\\\" \\\"The robot said, 'I am human.'\\\"\"" \
    ' '
  test_options \
    'foo"bar' \
    '-q' \
    "${os}" \
    '' \
    'printf "%s" "foo\"bar"'
  test_options \
    'foo"bar' \
    '-q' \
    "${os}" \
    '-e RUN_NON_ROOT_COMMAND="printf \"%s\" \"foo\\\"bar\""' \
    ' '
  test_options \
    'IO' \
    '-q' \
    "${os}" \
    '' \
    'printf "%s" "I\O"'
  test_options \
    'IO' \
    '-q' \
    "${os}" \
    '' \
    'printf "%s" "I\\O"'
  test_options \
    'I\O' \
    '-q' \
    "${os}" \
    '-e RUN_NON_ROOT_COMMAND="printf \"%s\" \"I\\O\""' \
    ' '
  test_options \
    '`' \
    '-q' \
    "${os}" \
    '' \
    'printf "%s" "\\\`"'
  test_options \
    '`' \
    '-q' \
    "${os}" \
    '-e RUN_NON_ROOT_COMMAND="printf \"%s\" \"\\\`\""' \
    ' '
  test_options \
    '/' \
    '-q' \
    "${os}" \
    '' \
    'printf "%s" "\`pwd\`"'
  test_options \
    '/' \
    '-q' \
    "${os}" \
    '-e RUN_NON_ROOT_COMMAND="printf \"%s\" \"\`pwd\`\""' \
    ' '
  test_options \
    '/' \
    '-q' \
    "${os}" \
    '' \
    'printf "%s" "\$(pwd)"'
  test_options \
    '/' \
    '-q' \
    "${os}" \
    '-e RUN_NON_ROOT_COMMAND="printf \"%s\" \"\$(pwd)\""' \
    ' '
  test_options \
    'I\O ` / /' \
    '-q' \
    "${os}" \
    '' \
    'printf "%s" "I\\O \\\` \`pwd\` \$(pwd)"'

  print_test_header 'Test calling run-non-root twice in a row.'

  test_options \
    'nonrootnonroot' \
    '-q -u 0' \
    "${os}" \
    '' \
    'sh -c "/usr/local/bin/run-non-root -q -- whoami && /usr/local/bin/run-non-root -q -- whoami"'

  print_test_header 'Test calling run-non-root as a non-root user.'

  test_options \
    'uid=1234(abcd) gid=5678(efgh) groups=5678(efgh)' \
    '-q -f efgh -g 5678 -t abcd -u 1234' \
    "${os}" \
    '' \
    'sh -c "/usr/local/bin/run-non-root -q -f foo -g 678 -t bar -u 234 -- id"'
  test_options \
    'foo bar' \
    '-q' \
    "${os}" \
    '' \
    "/usr/local/bin/run-non-root -q -- sh -c \"printf '%s' 'foo bar'\""

  print_test_header 'Test invalid inputs.'

  test_options \
    'su-exec: nonexistent: No such file or directory' \
    '-q' \
    "${os}" \
    '-e RUN_NON_ROOT_COMMAND="nonexistent command"' \
    ' '
  test_options \
    'su-exec: nonexistent: No such file or directory' \
    '-q' \
    "${os}" \
    '' \
    'nonexistent command'
  test_options \
    "${before_error}ERROR (5):${after_error} The GID must be a nonnegative integer; it is ( foo bar ).${reset}" \
    '--quiet --gid "foo bar"' \
    "${os}"
  test_options \
    "${before_error}ERROR (5):${after_error} The GID must be a nonnegative integer; it is ( -1 ).${reset}" \
    '--quiet --gid "-1"' \
    "${os}"
  test_options \
    "${before_error}ERROR (100):${after_error} We could not add the group ( foo bar ).${reset}" \
    '--quiet --group "foo bar"' \
    "${os}"
  test_options \
    "${before_error}ERROR (6):${after_error} The UID must be a nonnegative integer; it is ( foo bar ).${reset}" \
    '--quiet --uid "foo bar"' \
    "${os}"
  test_options \
    "${before_error}ERROR (6):${after_error} The UID must be a nonnegative integer; it is ( -1 ).${reset}" \
    '--quiet --uid "-1"' \
    "${os}"
  test_options \
    "${before_error}ERROR (100):${after_error} We could not add the group ( foo bar ).${reset}" \
    '--quiet --user "foo bar"' \
    "${os}"
  test_options \
    "${before_error}ERROR (100):${after_error} We could not add the group ( foo bar ) with ID ( 5000 ).${reset}" \
    '--quiet --gid 5000 --group "foo bar"' \
    "${os}"
  test_options \
    "${before_error}ERROR (200):${after_error} We could not add the user ( foo bar ).${reset}" \
    '--quiet --group "root" --user "foo bar"' \
    "${os}"
  test_options \
    "${before_error}ERROR (200):${after_error} We could not add the user ( foo bar ) with ID ( 5000 ).${reset}" \
    '--quiet --group "root" --uid 5000 --user "foo bar"' \
    "${os}"
  test_options \
    "${before_error}ERROR (5):${after_error} The GID must be a nonnegative integer; it is ( foo bar ).${reset}" \
    '-q' \
    "${os}" \
    '-e RUN_NON_ROOT_GID="foo bar"'
  test_options \
    "${before_error}ERROR (5):${after_error} The GID must be a nonnegative integer; it is ( -1 ).${reset}" \
    '-q' \
    "${os}" \
    '-e RUN_NON_ROOT_GID="-1"'
  test_options \
    "${before_error}ERROR (100):${after_error} We could not add the group ( foo bar ).${reset}" \
    '-q' \
    "${os}" \
    '-e RUN_NON_ROOT_GROUP="foo bar"'
  test_options \
    "${before_error}ERROR (6):${after_error} The UID must be a nonnegative integer; it is ( foo bar ).${reset}" \
    '-q' \
    "${os}" \
    '-e RUN_NON_ROOT_UID="foo bar"'
  test_options \
    "${before_error}ERROR (6):${after_error} The UID must be a nonnegative integer; it is ( -1 ).${reset}" \
    '-q' \
    "${os}" \
    '-e RUN_NON_ROOT_UID="-1"'
  test_options \
    "${before_error}ERROR (100):${after_error} We could not add the group ( foo bar ).${reset}" \
    '-q' \
    "${os}" \
    '-e RUN_NON_ROOT_USER="foo bar"'
  test_options \
    "${before_error}ERROR (100):${after_error} We could not add the group ( foo bar ) with ID ( 5000 ).${reset}" \
    '--quiet' \
    "${os}" \
    '-e RUN_NON_ROOT_GID=5000 -e RUN_NON_ROOT_GROUP="foo bar"'
  test_options \
    "${before_error}ERROR (200):${after_error} We could not add the user ( foo bar ).${reset}" \
    '--quiet' \
    "${os}" \
    '-e RUN_NON_ROOT_GROUP="root" -e RUN_NON_ROOT_USER="foo bar"'
  test_options \
    "${before_error}ERROR (200):${after_error} We could not add the user ( foo bar ) with ID ( 5000 ).${reset}" \
    '--quiet' \
    "${os}" \
    '-e RUN_NON_ROOT_GROUP="root" -e RUN_NON_ROOT_UID=5000 -e RUN_NON_ROOT_USER="foo bar"'

  case "${os}" in
    alpine)
      test_options \
        "ERROR (1): There was an error parsing the given options. You may need to (a) remove invalid options or (b) use -- to separate run-non-root's options from the command. Run run-non-root --help for more info. (From getopt: /usr/local/bin/run-non-root: unrecognized option: z)" \
        '-q -z' \
        "${os}" \
        '' \
        'echo'
      break
      ;;
    centos|debian|fedora|ubuntu)
      test_options \
        "${before_error}ERROR (1):${after_error} There was an error parsing the given options. You may need to (a) remove invalid options or (b) use -- to separate run-non-root's options from the command. Run run-non-root --help for more info. (From getopt: /usr/local/bin/run-non-root: invalid option -- 'z')${reset}" \
        '-q -z' \
        "${os}" \
        '' \
        'echo'
      break
      ;;
    *)
      printf "$(output_red)ERROR: We encountered an unexpected case ${case}.$(output_reset)\n"
      exit 1
      ;;
  esac

  print_test_header 'Test ps aux.'

  case "${os}" in
    alpine)
      test_options \
        'PID   USER     TIME  COMMAND    1 nonroot   0:00 ps aux' \
        '-q' \
        "${os}" \
        '' \
        'ps aux'
      test_options \
        'PID   USER     TIME  COMMAND    1 foobar    0:00 ps aux' \
        '-q -t foobar' \
        "${os}" \
        '' \
        'ps aux'
      test_options \
        'PID   USER     TIME  COMMAND    1 nonroot   0:00 tini -- ps aux   2 nonroot   0:00 ps aux' \
        '--init -q' \
        "${os}" \
        '' \
        'ps aux'
      test_options \
        'PID   USER     TIME  COMMAND    1 foobar    0:00 tini -- ps aux   2 foobar    0:00 ps aux' \
        '-iq -t foobar' \
        "${os}" \
        '' \
        'ps aux'
      break
      ;;
    centos|debian|fedora|ubuntu)
      test_options \
        'USER       PID CPU MEM    VSZ   RSS TTY      STAT START   TIME COMMANDnonroot      1 pts/0    Rs+   ps aux' \
        '-q' \
        "${os}" \
        '' \
        'ps aux'
      test_options \
        'USER       PID CPU MEM    VSZ   RSS TTY      STAT START   TIME COMMANDfoobar       1 pts/0    Rs+   ps aux' \
        '-q -t foobar' \
        "${os}" \
        '' \
        'ps aux'
      test_options \
        'USER       PID CPU MEM    VSZ   RSS TTY      STAT START   TIME COMMANDnonroot      1 pts/0    Ss    tini -- ps auxnonroot 2 pts/0    R+    ps aux' \
        '-iq' \
        "${os}" \
        '' \
        'ps aux'
      test_options \
        'USER       PID CPU MEM    VSZ   RSS TTY      STAT START   TIME COMMANDfoobar       1 pts/0    Ss    tini -- ps auxfoobar 2 pts/0    R+    ps aux' \
        '--init -q -t foobar' \
        "${os}" \
        '' \
        'ps aux'
      break
      ;;
    *)
      print_sn "$(output_red)ERROR: We encountered an unexpected case ${case}.$(output_reset)"
      exit 1
      ;;
  esac

  test_bare_image "${bare_image}" "${bare_image_command}"
}

test_options () {

  # Example from CentOS:
  # $ getent group
  # root:x:0:
  # bin:x:1:
  # daemon:x:2:
  # sys:x:3:
  # adm:x:4:
  # tty:x:5:
  # disk:x:6:
  # lp:x:7:
  # mem:x:8:
  # kmem:x:9:
  # wheel:x:10:
  # cdrom:x:11:
  # mail:x:12:
  # man:x:15:
  # dialout:x:18:
  # floppy:x:19:
  # games:x:20:
  # tape:x:33:
  # video:x:39:
  # ftp:x:50:
  # lock:x:54:
  # audio:x:63:
  # nobody:x:99:
  # users:x:100:
  # utmp:x:22:
  # utempter:x:35:
  # input:x:999:
  # systemd-journal:x:190:
  # systemd-network:x:192:
  # dbus:x:81:
  # nonroot:x:1000:

  # Example from CentOS:
  # $ getent passwd
  # root:x:0:0:root:/root:/bin/bash
  # bin:x:1:1:bin:/bin:/sbin/nologin
  # daemon:x:2:2:daemon:/sbin:/sbin/nologin
  # adm:x:3:4:adm:/var/adm:/sbin/nologin
  # lp:x:4:7:lp:/var/spool/lpd:/sbin/nologin
  # sync:x:5:0:sync:/sbin:/bin/sync
  # shutdown:x:6:0:shutdown:/sbin:/sbin/shutdown
  # halt:x:7:0:halt:/sbin:/sbin/halt
  # mail:x:8:12:mail:/var/spool/mail:/sbin/nologin
  # operator:x:11:0:operator:/root:/sbin/nologin
  # games:x:12:100:games:/usr/games:/sbin/nologin
  # ftp:x:14:50:FTP User:/var/ftp:/sbin/nologin
  # nobody:x:99:99:Nobody:/:/sbin/nologin
  # systemd-network:x:192:192:systemd Network Management:/:/sbin/nologin
  # dbus:x:81:81:System message bus:/:/sbin/nologin
  # nonroot:x:1000:1000::/home/nonroot:/bin/sh

  local expected="$1"
  local options="$2"
  local os="$3"
  local environment_variables="${4:-}"
  local command="-- ${5:-id}"
  local docker_command="$(
    print_s 'docker run'
    print_s " ${environment_variables}"
    print_s ' -it'
    print_s ' --rm'
    print_s " --volume $(pwd)/run-non-root.sh:/usr/local/bin/run-non-root:ro"
    print_s " creemama/run-non-root:1.3.0-${os}"
    print_s " ${options} "
    print_s " ${command}"
  )"
  print_sn "$(output_green)Testing $(output_cyan)${docker_command}$(output_reset)$(output_green) ... $(output_reset)"
  eval "${docker_command}" >&3 || printf "%s\n" "Exit Code: $?"
  actual="$(cat <&4)"
  print_snn "${actual}"
  assert_equals "${expected}" "${actual}"
}

test
