#!/bin/sh

assert_equals() {
  local expected="$1"
  local actual="`remove_control_characters "${2}"`"
  if [ "${expected}" != "${actual}" ]; then
    printf "$(output_red)ERROR: We expected \"$(output_bold)${expected}$(output_reset)$(output_red)\" but got \"$(output_bold)${actual}\"$(output_reset)\n"
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

output_green () {
  local_tput setaf 2
}

output_red () {
  local_tput setaf 1
}

output_reset () {
  local_tput sgr0
}

print_test_header() {
  local message="$1"
  printf "\n$(output_green)$(output_bold)${message}$(output_reset)\n"
}

remove_control_characters () {
  local string="$1"
  echo "${string}" | tr -d '[:cntrl:]' | sed -e "s/%//g"
}

test () {
  test_image "alpine:3.8" "run-non-root -- ps aux" "alpine"
  test_image "centos:7" "run-non-root -- ps aux" "centos"
  test_image "debian:9.5" "sh -c \"apt-get update && apt-get install -y procps && run-non-root ps aux\"" "debian"
  test_image "fedora:28" "sh -c \"dnf install -y procps-ng && run-non-root ps aux\"" "fedora"
  test_image "ubuntu:18.04" "run-non-root -- ps aux" "ubuntu"
}

test_bare_image () {
  local image="$1"
  local command="$2"

  printf "$(output_green)Testing ${image} ... $(output_reset)"

  local docker_command="docker run \
    -it \
    --rm \
    --volume \
    `pwd`/run-non-root.sh:/usr/local/bin/run-non-root:ro \
    ${image} \
    ${command}"
  eval "$docker_command" > test-output.txt
  if [ "$?" -ne 0 ]; then
    printf "$(output_red)ERROR: \"$(output_bold)$docker_command$(output_reset)$(output_red)\" failed.$(output_reset)\n"
    exit 1
  fi

  printf "$(output_green)DONE$(output_reset)\n"
}

test_image () {
  local bare_image="$1"
  local bare_image_command="$2"
  local os="$3"

  local mail_gid=
  local daemon_gid=
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
      printf "$(output_red)ERROR: We encountered an unexpected case ${case}.$(output_reset)\n"
      exit 1
      ;;
  esac

  local mail_gid_uid=
  local twelve_group_uid=
  local twelve_group_name=
  case "${os}" in
    alpine)
      mail_gid_uid=12
      twelve_group_uid=12
      twelve_group_name="mail"
      break
      ;;
    centos|fedora)
      mail_gid_uid=1000
      twelve_group_uid=1000
      twelve_group_name="mail"
      break
      ;;
    debian|ubuntu)
      mail_gid_uid=1000
      twelve_group_uid=12
      twelve_group_name="man"
      break
      ;;
    *)
      printf "$(output_red)ERROR: We encountered an unexpected case ${case}.$(output_reset)\n"
      exit 1
      ;;
  esac

  local before_error
  local after_error
  local reset
  case "${os}" in
    alpine|fedora)
      break
      ;;
    centos|debian|ubuntu)
      before_error="[31m[1m"
      after_error="(B[m[31m"
      reset="(B[m"
      break
      ;;
    *)
      printf "$(output_red)ERROR: We encountered an unexpected case ${case}.$(output_reset)\n"
      exit 1
      ;;
  esac

  print_test_header "No option exists."

  test_options \
    "uid=1000(nonroot) gid=1000(nonroot) groups=1000(nonroot)" \
    "-q" \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=1234(nonroot) groups=1234(nonroot)" \
    "-q -u 1234" \
    "${os}"
  test_options \
    "uid=1000(abcd) gid=1000(abcd) groups=1000(abcd)" \
    "-q -t abcd" \
    "${os}"
  test_options \
    "uid=1234(abcd) gid=1234(abcd) groups=1234(abcd)" \
    "-q -t abcd -u 1234" \
    "${os}"
  test_options \
    "uid=5678(nonroot) gid=5678(nonroot) groups=5678(nonroot)" \
    "-q -g 5678" \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=5678(nonroot) groups=5678(nonroot)" \
    "-q -g 5678 -u 1234" \
    "${os}"
  test_options \
    "uid=5678(abcd) gid=5678(abcd) groups=5678(abcd)" \
    "-q -g 5678 -t abcd" \
    "${os}"
  test_options \
    "uid=1234(abcd) gid=5678(abcd) groups=5678(abcd)" \
    "-q -g 5678 -t abcd -u 1234" \
    "${os}"
  test_options \
    "uid=1000(nonroot) gid=1000(efgh) groups=1000(efgh)" \
    "-q -f efgh" \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=1234(efgh) groups=1234(efgh)" \
    "-q -f efgh -u 1234" \
    "${os}"
  test_options \
    "uid=1000(abcd) gid=1000(efgh) groups=1000(efgh)" \
    "-q -f efgh -t abcd" \
    "${os}"
  test_options \
    "uid=1234(abcd) gid=1234(efgh) groups=1234(efgh)" \
    "-q -f efgh -t abcd -u 1234" \
    "${os}"
  test_options \
    "uid=5678(nonroot) gid=5678(efgh) groups=5678(efgh)" \
    "-q -f efgh -g 5678" \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=5678(efgh) groups=5678(efgh)" \
    "-q -f efgh -g 5678 -u 1234" \
    "${os}"
  test_options \
    "uid=5678(abcd) gid=5678(efgh) groups=5678(efgh)" \
    "-q -f efgh -g 5678 -t abcd" \
    "${os}"
  test_options \
    "uid=1234(abcd) gid=5678(efgh) groups=5678(efgh)" \
    "-q -f efgh -g 5678 -t abcd -u 1234" \
    "${os}"

  print_test_header "User ID 8 exists."

  test_options \
    "uid=8(mail) gid=${mail_gid}(mail) groups=${mail_gid}(mail)" \
    "-q -u 8" \
    "${os}"
  test_options \
    "uid=8(mail) gid=${mail_gid}(mail) groups=${mail_gid}(mail)" \
    "-q -t abcd -u 8" \
    "${os}"
  test_options \
    "uid=8(mail) gid=5678(nonroot) groups=5678(nonroot)" \
    "-q -g 5678 -u 8" \
    "${os}"
  test_options \
    "uid=8(mail) gid=5678(nonroot) groups=5678(nonroot)" \
    "-q -g 5678 -t abcd -u 8" \
    "${os}"
  test_options \
    "uid=8(mail) gid=1000(efgh) groups=1000(efgh)" \
    "-q -f efgh -u 8" \
    "${os}"
  test_options \
    "uid=8(mail) gid=1000(efgh) groups=1000(efgh)" \
    "-q -f efgh -t abcd -u 8" \
    "${os}"
  test_options \
    "uid=8(mail) gid=5678(efgh) groups=5678(efgh)" \
    "-q -f efgh -g 5678 -u 8" \
    "${os}"
  test_options \
    "uid=8(mail) gid=5678(efgh) groups=5678(efgh)" \
    "-q -f efgh -g 5678 -t abcd -u 8" \
    "${os}"

  print_test_header "Username mail exists."

  test_options \
    "uid=8(mail) gid=${mail_gid}(mail) groups=${mail_gid}(mail)" \
    "-q -t mail" \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=1234(nonroot) groups=1234(nonroot)" \
    "-q -t mail -u 1234" \
    "${os}"
  test_options \
    "uid=8(mail) gid=5678(nonroot) groups=5678(nonroot)" \
    "-q -g 5678 -t mail" \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=5678(nonroot) groups=5678(nonroot)" \
    "-q -g 5678 -t mail -u 1234" \
    "${os}"
  test_options \
    "uid=8(mail) gid=1000(efgh) groups=1000(efgh)" \
    "-q -f efgh -t mail" \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=1234(efgh) groups=1234(efgh)" \
    "-q -f efgh -t mail -u 1234" \
    "${os}"
  test_options \
    "uid=8(mail) gid=5678(efgh) groups=5678(efgh)" \
    "-q -f efgh -g 5678 -t mail" \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=5678(efgh) groups=5678(efgh)" \
    "-q -f efgh -g 5678 -t mail -u 1234" \
    "${os}"

  print_test_header "User ID 8 and username games exist."

  test_options \
    "uid=8(mail) gid=${mail_gid}(mail) groups=${mail_gid}(mail)" \
    "-q -t games -u 8" \
    "${os}"
  test_options \
    "uid=8(mail) gid=5678(nonroot) groups=5678(nonroot)" \
    "-q -g 5678 -t games -u 8" \
    "${os}"
  test_options \
    "uid=8(mail) gid=1000(efgh) groups=1000(efgh)" \
    "-q -f efgh -t games -u 8" \
    "${os}"
  test_options \
    "uid=8(mail) gid=5678(efgh) groups=5678(efgh)" \
    "-q -f efgh -g 5678 -t games -u 8" \
    "${os}"

  print_test_header "GID 12 exists."

  test_options \
    "uid=${twelve_group_uid}(nonroot) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    "-q -g 12" \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    "-q -g 12 -u 1234" \
    "${os}"
  test_options \
    "uid=${twelve_group_uid}(abcd) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    "-q -g 12 -t abcd" \
    "${os}"
  test_options \
    "uid=1234(abcd) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    "-q -g 12 -t abcd -u 1234" \
    "${os}"
  test_options \
    "uid=${twelve_group_uid}(nonroot) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    "-q -f efgh -g 12" \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    "-q -f efgh -g 12 -u 1234" \
    "${os}"
  test_options \
    "uid=${twelve_group_uid}(abcd) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    "-q -f efgh -g 12 -t abcd" \
    "${os}"
  test_options \
    "uid=1234(abcd) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    "-q -f efgh -g 12 -t abcd -u 1234" \
    "${os}"

  print_test_header "UID 8 and GID 100 exist."

  test_options \
    "uid=8(mail) gid=100(users) groups=100(users)" \
    "-q -g 100 -u 8" \
    "${os}"
  test_options \
    "uid=8(mail) gid=100(users) groups=100(users)" \
    "-q -g 100 -t abcd -u 8" \
    "${os}"
  test_options \
    "uid=8(mail) gid=100(users) groups=100(users)" \
    "-q -f efgh -g 100 -u 8" \
    "${os}"
  test_options \
    "uid=8(mail) gid=100(users) groups=100(users)" \
    "-q -f efgh -g 100 -t abcd -u 8" \
    "${os}"

  print_test_header "Username mail and GID 100 exist."

  test_options \
    "uid=8(mail) gid=100(users) groups=100(users)" \
    "-q -g 100 -t mail" \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=100(users) groups=100(users)" \
    "-q -g 100 -t mail -u 1234" \
    "${os}"
  test_options \
    "uid=8(mail) gid=100(users) groups=100(users)" \
    "-q -f efgh -g 100 -t mail" \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=100(users) groups=100(users)" \
    "-q -f efgh -g 100 -t mail -u 1234" \
    "${os}"

  print_test_header "UID 8, username nobody, and GID 100 exist."

  test_options \
    "uid=8(mail) gid=100(users) groups=100(users)" \
    "-q -g 100 -t nobody -u 8" \
    "${os}"
  test_options \
    "uid=8(mail) gid=100(users) groups=100(users)" \
    "-q -f efgh -g 100 -t nobody -u 8" \
    "${os}"

  print_test_header "Group name mail exists."

  test_options \
    "uid=${mail_gid_uid}(nonroot) gid=${mail_gid}(mail) groups=${mail_gid}(mail)" \
    "-q -f mail" \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=${mail_gid}(mail) groups=${mail_gid}(mail)" \
    "-q -f mail -u 1234" \
    "${os}"
  test_options \
    "uid=${mail_gid_uid}(abcd) gid=${mail_gid}(mail) groups=${mail_gid}(mail)" \
    "-q -f mail -t abcd" \
    "${os}"
  test_options \
    "uid=1234(abcd) gid=${mail_gid}(mail) groups=${mail_gid}(mail)" \
    "-q -f mail -t abcd -u 1234" \
    "${os}"
  test_options \
    "uid=5678(nonroot) gid=5678(nonroot) groups=5678(nonroot)" \
    "-q -f mail -g 5678" \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=5678(nonroot) groups=5678(nonroot)" \
    "-q -f mail -g 5678 -u 1234" \
    "${os}"
  test_options \
    "uid=5678(abcd) gid=5678(abcd) groups=5678(abcd)" \
    "-q -f mail -g 5678 -t abcd" \
    "${os}"
  test_options \
    "uid=1234(abcd) gid=5678(abcd) groups=5678(abcd)" \
    "-q -f mail -g 5678 -t abcd -u 1234" \
    "${os}"

  print_test_header "User ID 8 and group name daemon exist."

  test_options \
    "uid=8(mail) gid=${daemon_gid}(daemon) groups=${daemon_gid}(daemon)" \
    "-q -f daemon -u 8" \
    "${os}"
  test_options \
    "uid=8(mail) gid=${daemon_gid}(daemon) groups=${daemon_gid}(daemon)" \
    "-q -f daemon -t abcd -u 8" \
    "${os}"
  test_options \
    "uid=8(mail) gid=5678(nonroot) groups=5678(nonroot)" \
    "-q -f daemon -g 5678 -u 8" \
    "${os}"
  test_options \
    "uid=8(mail) gid=5678(nonroot) groups=5678(nonroot)" \
    "-q -f daemon -g 5678 -t abcd -u 8" \
    "${os}"

  print_test_header "Username mail and group name daemon exist."

  test_options \
    "uid=8(mail) gid=${daemon_gid}(daemon) groups=${daemon_gid}(daemon)" \
    "-q -f daemon -t mail" \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=${daemon_gid}(daemon) groups=${daemon_gid}(daemon)" \
    "-q -f daemon -t mail -u 1234" \
    "${os}"
  test_options \
    "uid=8(mail) gid=5678(nonroot) groups=5678(nonroot)" \
    "-q -f daemon -g 5678 -t mail" \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=5678(nonroot) groups=5678(nonroot)" \
    "-q -f daemon -g 5678 -t mail -u 1234" \
    "${os}"

  print_test_header "User ID 8, username games, and group name daemon exist."

  test_options \
    "uid=8(mail) gid=${daemon_gid}(daemon) groups=${daemon_gid}(daemon)" \
    "-q -f daemon -t games -u 8" \
    "${os}"
  test_options \
    "uid=8(mail) gid=5678(nonroot) groups=5678(nonroot)" \
    "-q -f daemon -g 5678 -t games -u 8" \
    "${os}"

  print_test_header "GID 12 and group name daemon exist."

  test_options \
    "uid=${twelve_group_uid}(nonroot) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    "-q -f daemon -g 12" \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    "-q -f daemon -g 12 -u 1234" \
    "${os}"
  test_options \
    "uid=${twelve_group_uid}(abcd) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    "-q -f daemon -g 12 -t abcd" \
    "${os}"
  test_options \
    "uid=1234(abcd) gid=12(${twelve_group_name}) groups=12(${twelve_group_name})" \
    "-q -f daemon -g 12 -t abcd -u 1234" \
    "${os}"

  print_test_header "UID 8, GID 100, and group name daemon exist."

  test_options \
    "uid=8(mail) gid=100(users) groups=100(users)" \
    "-q -f daemon -g 100 -u 8" \
    "${os}"
  test_options \
    "uid=8(mail) gid=100(users) groups=100(users)" \
    "-q -f daemon -g 100 -t abcd -u 8" \
    "${os}"

  print_test_header "Username mail, GID 100, and group name daemon exist."

  test_options \
    "uid=8(mail) gid=100(users) groups=100(users)" \
    "-q -f daemon -g 100 -t mail" \
    "${os}"
  test_options \
    "uid=1234(nonroot) gid=100(users) groups=100(users)" \
    "-q -f daemon -g 100 -t mail -u 1234" \
    "${os}"

  print_test_header "UID 8, username nobody, GID 100, and group name daemon exist."

  test_options \
    "uid=1234(abcd) gid=5678(efgh) groups=5678(efgh)" \
    "-q -f efgh -g 5678 -t abcd -u 1234" \
    "${os}"

  print_test_header "Test alternative option names."

  test_options \
    "uid=1234(abcd) gid=5678(efgh) groups=5678(efgh)" \
    "--quiet --group efgh --gid 5678 --user abcd --uid 1234" \
    "${os}"

  print_test_header "Test environment variables."

  test_options \
    "uid=9012(ijkl) gid=3456(mnop) groups=3456(mnop)" \
    "-q" \
    "${os}" \
    "-e RUN_NON_ROOT_GROUP_NAME=mnop -e RUN_NON_ROOT_GID=3456 -e RUN_NON_ROOT_USERNAME=ijkl -e RUN_NON_ROOT_UID=9012"
  test_options \
    "ijkl" \
    "-q" \
    "${os}" \
    "-e RUN_NON_ROOT_COMMAND=whoami -e RUN_NON_ROOT_GROUP_NAME=mnop -e RUN_NON_ROOT_GID=3456 -e RUN_NON_ROOT_USERNAME=ijkl -e RUN_NON_ROOT_UID=9012" \
    " "
  test_options \
    "uid=1234(abcd) gid=5678(efgh) groups=5678(efgh)" \
    "--quiet -f efgh -g 5678 --user abcd --uid 1234" \
    "${os}" \
    "-e RUN_NON_ROOT_GROUP_NAME=mnop -e RUN_NON_ROOT_GID=3456 -e RUN_NON_ROOT_USERNAME=ijkl -e RUN_NON_ROOT_UID=9012"

  print_test_header "Test commands with options and spaces."

  test_options \
    "nonroot" \
    "-q" \
    "${os}" \
    "" \
    "id -gn"
  test_options \
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit" \
    "-q" \
    "${os}" \
    "" \
    "echo \\\"Lorem ipsum dolor sit amet, consectetur adipiscing elit\\\""
  test_options \
    "mnop" \
    "-q" \
    "${os}" \
    "-e RUN_NON_ROOT_COMMAND=\"id -gn\" -e RUN_NON_ROOT_GROUP_NAME=mnop -e RUN_NON_ROOT_GID=3456 -e RUN_NON_ROOT_USERNAME=ijkl -e RUN_NON_ROOT_UID=9012" \
    " "
  test_options \
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit" \
    "-q" \
    "${os}" \
    "-e RUN_NON_ROOT_COMMAND=\"echo \\\"Lorem ipsum dolor sit amet, consectetur adipiscing elit\\\"\" -e RUN_NON_ROOT_GROUP_NAME=mnop -e RUN_NON_ROOT_GID=3456 -e RUN_NON_ROOT_USERNAME=ijkl -e RUN_NON_ROOT_UID=9012" \
    " "
  test_options \
    "foo bar" \
    "-q" \
    "${os}" \
    "" \
    "sh -c \"echo 'foo bar'\""

  print_test_header "Test calling run-non-root twice in a row."

  test_options \
    "nonrootgroupadd: group 'nonroot' already exists${before_error}ERROR (4):${after_error} We could not add the group nonroot.${reset}" \
    "-q -u 0" \
    "${os}" \
    "" \
    "sh -c \"/usr/local/bin/run-non-root -q -- whoami && /usr/local/bin/run-non-root -q -- whoami\""

  print_test_header "Test calling run-non-root as a non-root user."

  test_options \
    "uid=1234(abcd) gid=5678(efgh) groups=5678(efgh)" \
    "-q -f efgh -g 5678 -t abcd -u 1234" \
    "${os}" \
    "" \
    "sh -c \"/usr/local/bin/run-non-root -q -f foo -g 678 -t bar -u 234 -- id\""
  test_options \
    "foo bar" \
    "-q" \
    "${os}" \
    "" \
    "/usr/local/bin/run-non-root -q -- sh -c \"echo 'foo bar'\""

  print_test_header "Test invalid inputs."

  test_options \
    "su-exec: nonexistent: No such file or directory" \
    "-q" \
    "${os}" \
    "-e RUN_NON_ROOT_COMMAND=\"nonexistent command\"" \
    " "
  test_options \
    "su-exec: nonexistent: No such file or directory" \
    "-q" \
    "${os}" \
    "" \
    "nonexistent command"
  test_options \
    "${before_error}ERROR (2):${after_error} We expected GID to be an integer, but it was foo bar.${reset}" \
    "--quiet --gid \"foo bar\"" \
    "${os}"
  test_options \
    "groupadd: invalid group ID '-1'${before_error}ERROR (4):${after_error} We could not add the group nonroot with ID -1.${reset}" \
    "--quiet --gid \"-1\"" \
    "${os}"
  test_options \
    "groupadd: 'foo bar' is not a valid group name${before_error}ERROR (4):${after_error} We could not add the group foo bar.${reset}" \
    "--quiet --group \"foo bar\"" \
    "${os}"
  test_options \
    "${before_error}ERROR (3):${after_error} We expected UID to be an integer, but it was foo bar.${reset}" \
    "--quiet --uid \"foo bar\"" \
    "${os}"
  test_options \
    "groupadd: invalid group ID '-1'${before_error}ERROR (4):${after_error} We could not add the group nonroot with ID -1.${reset}" \
    "--quiet --uid \"-1\"" \
    "${os}"
  test_options \
    "groupadd: 'foo bar' is not a valid group name${before_error}ERROR (4):${after_error} We could not add the group foo bar.${reset}" \
    "--quiet --user \"foo bar\"" \
    "${os}"
  test_options \
    "${before_error}ERROR (2):${after_error} We expected GID to be an integer, but it was foo bar.${reset}" \
    "-q" \
    "${os}" \
    "-e RUN_NON_ROOT_GID=\"foo bar\""
  test_options \
    "groupadd: invalid group ID '-1'${before_error}ERROR (4):${after_error} We could not add the group nonroot with ID -1.${reset}" \
    "-q" \
    "${os}" \
    "-e RUN_NON_ROOT_GID=\"-1\""
  test_options \
    "groupadd: 'foo bar' is not a valid group name${before_error}ERROR (4):${after_error} We could not add the group foo bar.${reset}" \
    "-q" \
    "${os}" \
    "-e RUN_NON_ROOT_GROUP_NAME=\"foo bar\""
  test_options \
    "${before_error}ERROR (3):${after_error} We expected UID to be an integer, but it was foo bar.${reset}" \
    "-q" \
    "${os}" \
    "-e RUN_NON_ROOT_UID=\"foo bar\""
  test_options \
    "groupadd: invalid group ID '-1'${before_error}ERROR (4):${after_error} We could not add the group nonroot with ID -1.${reset}" \
    "-q" \
    "${os}" \
    "-e RUN_NON_ROOT_UID=\"-1\""
  test_options \
    "groupadd: 'foo bar' is not a valid group name${before_error}ERROR (4):${after_error} We could not add the group foo bar.${reset}" \
    "-q" \
    "${os}" \
    "-e RUN_NON_ROOT_USERNAME=\"foo bar\""

  print_test_header "Test ps aux."

  case "${os}" in
    alpine)
      test_options \
        "PID   USER     TIME  COMMAND    1 nonroot   0:00 ps aux" \
        "-q" \
        "${os}" \
        "" \
        "ps aux"
      test_options \
        "PID   USER     TIME  COMMAND    1 foobar    0:00 ps aux" \
        "-q -t foobar" \
        "${os}" \
        "" \
        "ps aux"
      break
      ;;
    centos|debian|fedora|ubuntu)
      test_options \
        "USER       PID CPU MEM    VSZ   RSS TTY      STAT START   TIME COMMANDnonroot      1 pts/0    Rs+   ps aux" \
        "-q" \
        "${os}" \
        "" \
        "ps aux"
      test_options \
        "USER       PID CPU MEM    VSZ   RSS TTY      STAT START   TIME COMMANDfoobar       1 pts/0    Rs+   ps aux" \
        "-q -t foobar" \
        "${os}" \
        "" \
        "ps aux"
      break
      ;;
    *)
      printf "$(output_red)ERROR: We encountered an unexpected case ${case}.$(output_reset)\n"
      exit 1
      ;;
  esac

  print_test_header "Test bare image."

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
  local environment_variables="$4"
  local command="-- ${5:-id}"
  printf "$(output_green)Testing ${options}${environment_variables:+ ${environment_variables}} on ${os} ... $(output_reset)"
  local docker_command="docker run \
    ${environment_variables} \
    -it \
    --rm \
    --volume $(pwd)/run-non-root.sh:/usr/local/bin/run-non-root:ro \
    creemama/run-non-root:0.0.0-${os} \
    ${options} \
    ${command}"
  eval "${docker_command}" > test-output.txt
  actual=`cat test-output.txt`

  # Modify ps aux output to get consistent output.
  # nonroot      1  4.0  0.1  49588  3116 pts/0    Rs+  00:00   00:00 ps aux
  local integer="[0-9][0-9]*"
  local whitespace="[[:blank:]][[:blank:]]*"
  local float="[0-9][0-9]*\.[0-9][0-9]*"
  local time="[0-9][0-9]*:[0-9][0-9]*"
  actual=`echo "${actual}" | sed -e "s/\(${integer}\)${whitespace}${float}${whitespace}${float}${whitespace}${integer}${whitespace}${integer}/\1/g"`
  actual=`echo "${actual}" | sed -e "s/${time}${whitespace}${time}//g"`

  assert_equals "${expected}" "${actual}"
  printf "$(output_green)DONE$(output_reset)\n"
}

test
