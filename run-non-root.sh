#!/bin/sh

RUN_NON_ROOT_VERSION=1.0.1

print_help () {
  cat << EOF

Usage:
  run-non-root [options] [--] [COMMAND] [ARGS...]

Run Linux commands as a non-root user, creating a non-root user if necessary.

Options:
  -d, --debug             Output debug information; using --quiet does not
                          silence debug output.
  -f, --group GROUP_NAME  The group name to use when executing the command; the
                          default group name is USERNAME or nonroot; this
                          option is ignored if we are already running as a
                          non-root user or if the GID already exists; this
                          option overrides the RUN_NON_ROOT_GROUP environment
                          variable.
  -g, --gid GID           The group ID to use when executing the command; the
                          default GID is UID or a new ID determined by
                          groupadd; this option is ignored if we are already
                          running as a non-root user; this option overrides the
                          RUN_NON_ROOT_GID environment variable.
  -h, --help              Output this help message and exit.
  -i, --init              Run an init (the tini command) that forwards signals
                          and reaps processes; this matches the docker run
                          option --init.
  -q, --quiet             Do not output "Running ( COMMAND ) as USER_INFO ..."
                          or warnings; this option does not silence --debug
                          output.
  -t, --user USERNAME     The username to use when executing the command; the
                          default is nonroot; this option is ignored if we are
                          already running as a non-root user or if the UID
                          already exists; this option overrides the
                          RUN_NON_ROOT_USER environment variable.
  -u, --uid UID           The user ID to use when executing the command; the
                          default UID is GID or a new ID determined by
                          useraddd; this option is ignored if we are already
                          running as a non-root user; this option overrides the
                          RUN_NON_ROOT_UID environment variable.
  -v, --version           Ouput the version number of run-non-root.

Environment Variables:
  RUN_NON_ROOT_COMMAND    The command to execute if a command is not given; the
                          default is sh.
  RUN_NON_ROOT_GID        The group ID to use when executing the command; see
                          the --gid option for more info.
  RUN_NON_ROOT_GROUP      The group name to use when executing the command; see
                          the --group option for more info.
  RUN_NON_ROOT_UID        The user ID to use when executing the command; see
                          the --uid option for more info.
  RUN_NON_ROOT_USER       The username to use when executing the command; see
                          the --user option for more info.

Examples:
  # Run sh as a non-root user.
  run-non-root

  # Run id as a non-root user.
  run-non-root -- id

  # Run id as a non-root user using options and the given user specification.
  run-non-root -f ec2-user -g 1000 -t ec2-user -u 1000 -- id

  # Run id as a non-root user using environment variables
  # and the given user specification.
  export RUN_NON_ROOT_GID=1000
  export RUN_NON_ROOT_GROUP=ec2-user
  export RUN_NON_ROOT_UID=1000
  export RUN_NON_ROOT_USER=ec2-user
  run-non-root -- id

Version: ${RUN_NON_ROOT_VERSION}

EOF
}

add_group() {
  local debug="$1"
  local local_gid="$2"
  local local_group_name="$3"
  local quiet="$4"
  local return_gid="$5"
  local return_group_name="$6"
  local uid="$7"
  local username="$8"

  if [ -z "${local_group_name}" ]; then
    does_group_exist "${username}"
    local group_name_as_username_exists="$?"
    if [ "${group_name_as_username_exists}" -eq 0 ]; then
      if [ "${username}" = "nonroot" ]; then
        # The nonroot group already exists.
        eval $return_gid="'$(id -gn ${nonroot})'"
        eval $return_group_name="'nonroot'"
        return
      fi
      local_group_name="nonroot"
    else
      local_group_name="${username}"
    fi
  fi

  if [ -z "${local_gid}" ] \
  && [ ! -z "${uid}" ] \
  && [ "${uid}" -eq "${uid}" ] 2> /dev/null; then
    does_group_exist "${uid}"
    local gid_as_uid="$?"
    if [ "${gid_as_uid}" -ne 0 ]; then
      local_gid="${uid}"
    fi
  fi

  local gid_option=
  if [ ! -z "${local_gid}" ]; then
    gid_option="--gid ${local_gid}"
  fi

  check_for_groupadd "${debug}" "${quiet}"

  if [ "${debug}" = "y" ]; then
    print_ns "$(output_cyan)Executing$(output_reset) groupadd ${gid_option} \"${local_group_name}\" ... "
  fi
  # "groupadd(8) - Linux man page"
  # https://linux.die.net/man/8/groupadd
  # gid_option is unquoted.
  groupadd ${gid_option} "${local_group_name}"
  if [ "$?" -ne 0 ]; then
    local gid_part=
    if [ ! -z "${local_gid}" ]; then
      gid_part=" with ID ( ${local_gid} )"
    fi
    exit_with_error 100 "We could not add the group ( ${local_group_name} )${gid_part}."
  fi
  if [ "${debug}" = "y" ]; then
    print_sn "$(output_cyan)DONE$(output_reset)"
  fi

  if [ -z "${local_gid}" ]; then
    local_gid="$(getent group ${local_group_name} | awk -F ":" '{print $3}')"
  fi

  eval $return_gid="'${local_gid}'"
  eval $return_group_name="'${local_group_name}'"
}

add_user() {
  local debug="$1"
  local gid="$2"
  local quiet="$3"
  local uid="$4"
  local username="$5"

  if [ -z "${uid}" ]; then
    does_user_exist "${gid}"
    local uid_as_gid_exists="$?"
    if [ "${uid_as_gid_exists}" -ne 0 ]; then
      uid="${gid}"
    fi
  fi

  local uid_option=
  if [ ! -z "${uid}" ]; then
    uid_option="--uid ""${uid}"
  fi

  check_for_useradd "${debug}" "${quiet}"

  # In alpine:3.7, useradd set the shell to /bin/bash even though it doesn't exist.
  # As such, we set "--shell /bin/sh".
  if [ "${debug}" = "y" ]; then
    print_nsn "$(output_cyan)Executing$(output_reset) useradd \\ "
    print_sn "  --create-home \\ "
    print_sn "  --gid \"${gid}\" \\ "
    print_sn "  --no-log-init \\ "
    print_sn "  --shell /bin/sh \\ "
    if [ ! -z "${uid_option}" ]; then
      print_sn "  ${uid_option} \\ "
    fi
    print_s "  \"${username}\" ... "
  fi
  # "useradd(8) - Linux man page"
  # https://linux.die.net/man/8/useradd
  # uid_option is unquoted.
  useradd \
    --create-home \
    --gid "${gid}" \
    --no-log-init \
    --shell /bin/sh \
    ${uid_option} \
    "${username}"
  if [ "$?" -ne 0 ]; then
    local uid_part=
    if [ ! -z "${uid}" ]; then
      uid_part=" with ID ( ${uid} )"
    fi
    exit_with_error 200 "We could not add the user ( ${username} )${uid_part}."
  fi
  if [ "${debug}" = "y" ]; then
    print_sn "$(output_cyan)DONE$(output_reset)"
  fi
}

apk_add_shadow () {
  local debug="$1"
  local quiet="$2"
  if [ -z "${quiet}" ]; then
    print_warning "To speed up this command, call \"apk update && apk add shadow\" before executing this command."
  fi
  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_nsn "$(output_cyan)Executing$(output_reset) apk update && apk add shadow ..."
  fi
  if [ -z "${quiet}" ]; then
    apk update && apk add shadow
  else
    apk update > /dev/null && apk add shadow > /dev/null
  fi
  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_sn "$(output_cyan)DONE$(output_reset)"
  fi
}

apk_add_su_exec () {
  local debug="$1"
  local quiet="$2"
  if [ -z "${quiet}" ]; then
    print_warning "To speed up this command, call \"apk update && apk add su-exec\" before executing this command."
  fi
  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_nsn "$(output_cyan)Executing$(output_reset) apk update && apk add su-exec ..."
  fi
  if [ -z "${quiet}" ]; then
    apk update && apk add su-exec
  else
    apk update > /dev/null && apk add su-exec > /dev/null
  fi
  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_sn "$(output_cyan)DONE$(output_reset)"
  fi
}

apk_add_tini () {
  local debug="$1"
  local quiet="$2"

  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_nsn "$(output_cyan)Executing$(output_reset) wget -O /usr/local/bin/tini https://github.com/krallin/tini/releases/download/v0.18.0/tini-static ..."
  fi
  if [ -z "${quiet}" ]; then
    wget -O /usr/local/bin/tini https://github.com/krallin/tini/releases/download/v0.18.0/tini-static
  else
    wget -O /usr/local/bin/tini https://github.com/krallin/tini/releases/download/v0.18.0/tini-static > /dev/null 2>&1
  fi
  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_sn "$(output_cyan)DONE$(output_reset)"
  fi

  chmod +x /usr/local/bin/tini
}

apt_get_install_su_exec () {
  local debug="$1"
  local quiet="$2"

  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_nsn "$(output_cyan)Executing$(output_reset) apt-get update ..."
  fi
  if [ -z "${quiet}" ]; then
    apt-get update
  else
    apt-get update > /dev/null 2>&1
  fi
  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_sn "$(output_cyan)DONE$(output_reset)"
  fi

  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_nsn "$(output_cyan)Executing$(output_reset) apt-get install -y curl gcc make unzip ..."
  fi
  if [ -z "${quiet}" ]; then
    apt-get install -y curl gcc make unzip
  else
    apt-get install -y curl gcc make unzip > /dev/null 2>&1
  fi
  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_sn "$(output_cyan)DONE$(output_reset)"
  fi

  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_nsn "$(output_cyan)Executing$(output_reset) curl -L https://github.com/ncopa/su-exec/archive/dddd1567b7c76365e1e0aac561287975020a8fad.zip -o su-exec.zip ..."
  fi
  if [ -z "${quiet}" ]; then
    curl -L https://github.com/ncopa/su-exec/archive/dddd1567b7c76365e1e0aac561287975020a8fad.zip -o su-exec.zip
  else
    curl --silent -L https://github.com/ncopa/su-exec/archive/dddd1567b7c76365e1e0aac561287975020a8fad.zip -o su-exec.zip
  fi
  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_sn "$(output_cyan)DONE$(output_reset)"
  fi

  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_nsn "$(output_cyan)Installing$(output_reset) su-exec ..."
  fi
  if [ -z "${quiet}" ]; then
    unzip su-exec.zip
    cd su-exec-dddd1567b7c76365e1e0aac561287975020a8fad
    make
    mv su-exec /usr/local/bin
    cd ..
    rm -rf su-exec-dddd1567b7c76365e1e0aac561287975020a8fad
  else
    unzip su-exec.zip > /dev/null
    cd su-exec-dddd1567b7c76365e1e0aac561287975020a8fad
    make > /dev/null
    mv su-exec /usr/local/bin
    cd ..
    rm -rf su-exec-dddd1567b7c76365e1e0aac561287975020a8fad
  fi
  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_sn "$(output_cyan)DONE$(output_reset)"
  fi
}

apt_get_install_tini () {
  local debug="$1"
  local quiet="$2"

  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_nsn "$(output_cyan)Executing$(output_reset) apt-get update ..."
  fi
  if [ -z "${quiet}" ]; then
    apt-get update
  else
    apt-get update > /dev/null 2>&1
  fi
  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_sn "$(output_cyan)DONE$(output_reset)"
  fi

  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_nsn "$(output_cyan)Executing$(output_reset) apt-get install -y curl ..."
  fi
  if [ -z "${quiet}" ]; then
    apt-get install -y curl
  else
    apt-get install -y curl > /dev/null 2>&1
  fi
  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_sn "$(output_cyan)DONE$(output_reset)"
  fi

  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_nsn "$(output_cyan)Executing$(output_reset) curl -L https://github.com/krallin/tini/releases/download/v0.18.0/tini-static -o /usr/local/bin/tini ..."
  fi
  if [ -z "${quiet}" ]; then
    curl -L https://github.com/krallin/tini/releases/download/v0.18.0/tini-static -o /usr/local/bin/tini
  else
    curl --silent -L https://github.com/krallin/tini/releases/download/v0.18.0/tini-static -o /usr/local/bin/tini
  fi
  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_sn "$(output_cyan)DONE$(output_reset)"
  fi

  chmod +x /usr/local/bin/tini
}

check_for_getopt () {
  command -v getopt > /dev/null
  if [ "$?" -ne 0 ]; then
    command -v yum > /dev/null
    if [ "$?" -eq 0 ]; then
      yum install -y util-linux-ng > /dev/null 2>&1
    fi
  fi
}

check_for_groupadd () {
  local debug="$1"
  local quiet="$2"
  command -v groupadd > /dev/null
  if [ "$?" -ne 0 ]; then
    command -v apk > /dev/null
    if [ "$?" -eq 0 ]; then
      apk_add_shadow "${debug}" "${quiet}"
    fi
  fi
}

check_for_su_exec () {
  local debug="$1"
  local quiet="$2"
  command -v su-exec > /dev/null
  if [ "$?" -ne 0 ]; then

    # "Package Management Basics: apt, yum, dnf, pkg"
    # https://www.digitalocean.com/community/tutorials/package-management-basics-apt-yum-dnf-pkg.

    command -v apk > /dev/null
    if [ "$?" -eq 0 ]; then
      apk_add_su_exec "${debug}" "${quiet}"
      return "$?"
    fi
    command -v apt-get > /dev/null
    if [ "$?" -eq 0 ]; then
      apt_get_install_su_exec "${debug}" "${quiet}"
      return "$?"
    fi
    command -v yum > /dev/null
    if [ "$?" -eq 0 ]; then
      yum_install_su_exec "${debug}" "${quiet}"
      return "$?"
    fi
  fi
}

check_for_tini() {
  local debug="$1"
  local quiet="$2"
  command -v tini > /dev/null
  if [ "$?" -ne 0 ]; then
    command -v apk > /dev/null
    if [ "$?" -eq 0 ]; then
      apk_add_tini "${debug}" "${quiet}"
      return "$?"
    fi
    command -v apt-get > /dev/null
    if [ "$?" -eq 0 ]; then
      apt_get_install_tini "${debug}" "${quiet}"
      return "$?"
    fi
    command -v yum > /dev/null
    if [ "$?" -eq 0 ]; then
      yum_install_tini "${debug}" "${quiet}"
      return "$?"
    fi
  fi
}

check_for_useradd () {
  local debug="$1"
  local quiet="$2"
  command -v useradd > /dev/null
  if [ "$?" -ne 0 ]; then
    command -v apk > /dev/null
    if [ "$?" -eq 0 ]; then
      apk_add_shadow "${debug}" "${quiet}"
    fi
  fi
  command -v apk > /dev/null
  if [ "$?" -eq 0 ]; then
    # In alpine:3.7, unless we execute the following command, we get the
    # following error after calling useradd:
    # Creating mailbox file: No such file or directory
    if [ "${debug}" = "y" ]; then
      print_ns "$(output_cyan)Executing$(output_reset) mkdir -p /var/mail ... "
    fi
    mkdir -p /var/mail
    if [ "${debug}" = "y" ]; then
      print_sn "$(output_cyan)DONE$(output_reset)"
    fi
  fi
}

does_group_exist () {
  local gid_or_group_name="$1"
  if [ -z "${gid_or_group_name}" ]; then
    return 1
  else
    getent group "${gid_or_group_name}" > /dev/null 2>&1
  fi
}

does_user_exist () {
  local uid_or_username="$1"
  if [ -z "${uid_or_username}" ]; then
    return 1
  else
    getent passwd "${uid_or_username}" > /dev/null 2>&1
  fi
}

escape_double_quotation_marks() {
  print_s "$1" | sed "s/\"/\\\\\"/g"
}

exit_with_error () {
  local exit_code="$1"
  local message="$2"
  (>&2 print_sn "$(output_red)$(output_bold)ERROR (${exit_code}):$(output_reset)$(output_red) ${message}$(output_reset)")
  exit "${exit_code}"
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

main () {
  local command="${RUN_NON_ROOT_COMMAND}"
  local debug=
  local gid="${RUN_NON_ROOT_GID}"
  local group_name="${RUN_NON_ROOT_GROUP}"
  local init=
  local quiet=
  local uid="${RUN_NON_ROOT_UID}"
  local username="${RUN_NON_ROOT_USER}"

  # "How do I parse command line arguments in Bash?"
  # https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash

  # "How create a temporary file in shell script?"
  # https://unix.stackexchange.com/questions/181937/how-create-a-temporary-file-in-shell-script

  check_for_getopt
  tmpfile=$(mktemp)
  local parsed_options="$(getopt \
    --options=df:g:hiqt:u:v \
    --longoptions=debug,gid:,group:,help,init,quiet,uid:,user:,version \
    --name "$0" \
    -- "$@" 2> "${tmpfile}")"
  local getopt_warnings="$(cat "${tmpfile}")"
  rm "${tmpfile}"
  if [ ! -z "${getopt_warnings}" ]; then
    exit_with_error 1 "There was an error parsing the given options. You may need to (a) remove invalid options or (b) use -- to separate run-non-root's options from the command. Run run-non-root --help for more info.$(printf "\n" "")${getopt_warnings}"
  fi

  eval set -- "${parsed_options}"
  while true; do
    case "$1" in
      -d|--debug)
        debug="y"
        shift
        ;;
      -f|--group)
        group_name="$2"
        shift 2
        ;;
      -g|--gid)
        gid="$2"
        shift 2
        ;;
      -h|--help)
        print_help
        exit 0
        ;;
      -i|--init)
        init="y"
        shift
        ;;
      -q|--quiet)
        quiet="y"
        shift
        ;;
      -t|--user)
        username="$2"
        shift 2
        ;;
      -u|--uid)
        uid="$2"
        shift 2
        ;;
      -v|--version)
        print_sn "${RUN_NON_ROOT_VERSION}"
        exit 0
        ;;
      --)
        shift
        break
        ;;
      *)
        exit_with_error 2 "There was an error parsing the given options ( $@ )."
        ;;
    esac
  done

  # The following if statement ensures that we preserve quotation marks in commands.

  # For example, if the user enters
  # run-non-root -- echo "foo bar"
  # we want the command to be
  # echo "foo bar"
  # and not
  # echo foo bar

  if [ ! -z "$1" ]; then
    command="$(stringify_arguments "$@")"
  fi

  if [ "${debug}" = "y" ]; then
    cat << EOF

$(output_cyan)Command Options:$(output_reset)
  $(output_cyan)command=$(output_reset)${command}
  $(output_cyan)debug=$(output_reset)${debug}
  $(output_cyan)gid=$(output_reset)${gid}
  $(output_cyan)group_name=$(output_reset)${group_name}
  $(output_cyan)init=$(output_reset)${init}
  $(output_cyan)quiet=$(output_reset)${quiet}
  $(output_cyan)uid=$(output_reset)${uid}
  $(output_cyan)username=$(output_reset)${username}
EOF
  fi

  # Since we are using eval to execute groupadd and useradd, ensure that users
  # do not try to inject code via group_name or username through the clever
  # usage of quotation marks.

  # For example,
  # malicious_string="foo\"; echo \"bar"
  # command=$(echo echo \"${malicious_string}\")
  # echo "${command}"
  # eval "${command}"
  # These commands output:
  # echo "foo"; echo "bar"
  # foo
  # bar

  if ! [ -z "${group_name}" ] \
  && test_contains_double_quotation_mark "${group_name}"; then
    exit_with_error 3 "The group name must not contain a double quotation mark; it is ( ${group_name} )."
  fi

  if ! [ -z "${username}" ] \
  && test_contains_double_quotation_mark "${username}"; then
    exit_with_error 4 "The username must not contain a double quotation mark; it is ( ${username} )."
  fi

  if ! [ -z "${gid}" ] && (! test_is_integer "${gid}" || [ "${gid}" -lt 0 ]); then
    exit_with_error 5 "The GID must be a nonnegative integer; it is ( ${gid} )."
  fi

  if ! [ -z "${uid}" ] && (! test_is_integer "${uid}" || [ "${uid}" -lt 0 ]); then
    exit_with_error 6 "The UID must be a nonnegative integer; it is ( ${uid} )."
  fi

  run_non_root \
    "${command}" \
    "${debug}" \
    "${gid}" \
    "${group_name}" \
    "${init}" \
    "${quiet}" \
    "${uid}" \
    "${username}"
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

output_yellow () {
  local_tput setaf 3
}

print_ns () {
  printf "\n%s" "${1}"
}

print_nsn () {
  printf "\n%s\n" "${1}"
}

print_nsnn () {
  printf "\n%s\n\n" "${1}"
}

print_s () {
  printf "%s" "${1}"
}

print_sn () {
  printf "%s\n" "${1}"
}

print_warning () {
  print_nsn "$(output_yellow)$(output_bold)WARNING:$(output_reset)$(output_yellow) $1$(output_reset)"
}

run_as_current_user () {
  local command="${1:-sh}"
  local debug="$2"
  local init="$3"
  local quiet="$4"

  local tini_part
  if [ "${init}" = "y" ]; then
    check_for_tini "${debug}" "${quiet}"
    tini_part="tini -- "
  fi

  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_warning "You are already running as a non-root user. We have ignored all group and user options."
    print_nsnn "$(output_green)Running ( ${tini_part}$(output_bold)${command}$(output_reset)$(output_green) ) as $(id) ...$(output_reset)"
  fi
  # If we had not used eval, then commands like
  # sh -c "ls -al" or sh -c "echo 'foo bar'"
  # would have errored with
  # /usr/local/bin/run-non-root: line 1: exec sh -c "ls -al": not found
  # 'ls: line 1: syntax error: unterminated quoted string
  # or
  # 'foo: line 1: syntax error: unterminated quoted string
  eval "exec ${tini_part}${command}"
}

run_as_non_root_user () {

  # "Best practices for writing Dockerfiles"
  # https://docs.docker.com/develop/develop-images/dockerfile_best-practices/
  # The article gives the following example for creating a non-root user and group:
  # groupadd -r postgres && useradd --no-log-init -r -g postgres postgres

  # "Processes In Containers Should Not Run As Root"
  # https://medium.com/@mccode/processes-in-containers-should-not-run-as-root-2feae3f0df3b
  # The article gives the following example for creating a non-root user and group:
  # groupadd -g 999 appuser && useradd -r -u 999 -g appuser appuser

  # List all groups: getent group
  # List all users: getent passwd

  local command="${1:-sh}"
  local debug="$2"
  local gid="$3"
  local group_name="$4"
  local init="$5"
  local quiet="$6"
  local uid="$7"
  local username="$8"

  does_group_exist "${gid}"
  local gid_exists="$?"

  does_group_exist "${group_name}"
  local group_name_exists="$?"

  does_user_exist "${uid}"
  local uid_exists="$?"

  does_user_exist "${username}"
  local username_exists="$?"

  local create_user=
  local create_group=

  # "Returning Values from Bash Functions"
  # https://www.linuxjournal.com/content/return-values-bash-functions

  update_user_spec \
    "${uid}" \
    "${username}" \
    "${quiet}" \
    uid \
    username \
    create_user \
    "${uid_exists}" \
    "${username_exists}"
  # After this statement, username is set; uid might not be set.

  update_group_spec \
    "${create_user}" \
    "${gid_exists}" \
    "${group_name_exists}" \
    "${gid}" \
    "${group_name}" \
    "${quiet}" \
    gid \
    group_name \
    create_group \
    "${username}"

  if [ ! -z "${create_group}" ]; then
    add_group \
      "${debug}" \
      "${gid}" \
      "${group_name}" \
      "${quiet}" \
      gid \
      group_name \
      "${uid}" \
      "${username}"
  fi

  if [ ! -z "${create_user}" ]; then
    add_user \
      "${debug}" \
      "${gid}" \
      "${quiet}" \
      "${uid}" \
      "${username}"
  fi

  local tini_part
  if [ "${init}" = "y" ]; then
    check_for_tini "${debug}" "${quiet}"
    tini_part="tini -- "
  fi

  check_for_su_exec "${debug}" "${quiet}"
  if [ "${debug}" = "y" ] || [ -z ${quiet} ]; then
    print_nsnn "$(output_green)Running ( su-exec ${username}:${gid} ${tini_part}$(output_bold)${command}$(output_reset)$(output_green) ) as $(id ${username}) ...$(output_reset)"
  fi
  # If we had not used eval, then commands like
  # sh -c "ls -al" or sh -c "echo 'foo bar'"
  # would have errored with
  # /usr/local/bin/run-non-root: line 1: exec sh -c "ls -al": not found
  # 'ls: line 1: syntax error: unterminated quoted string
  # or
  # 'foo: line 1: syntax error: unterminated quoted string
  eval "exec su-exec ${username}:${gid} ${tini_part}${command}"
}

run_non_root () {
  local command="$1"
  local debug="$2"
  local gid="$3"
  local group_name="$4"
  local init="$5"
  local quiet="$6"
  local uid="$7"
  local username="$8"

  if [ "$(whoami)" = "root" ]; then
    run_as_non_root_user \
      "${command}" \
      "${debug}" \
      "${gid}" \
      "${group_name}" \
      "${init}" \
      "${quiet}" \
      "${uid}" \
      "${username}"
  else
    run_as_current_user \
      "${command}" \
      "${debug}" \
      "${init}" \
      "${quiet}"
  fi
}

stringify_arguments () {
  # "How to use arguments like $1 $2 … in a for loop?"
  # https://unix.stackexchange.com/questions/314032/how-to-use-arguments-like-1-2-in-a-for-loop
  local command=$(escape_double_quotation_marks "${1}")
  shift
  for arg
    # "How to check if a string has spaces in Bash shell"
    # https://stackoverflow.com/questions/1473981/how-to-check-if-a-string-has-spaces-in-bash-shell
    do case "${arg}" in
      *\ *)
        command="${command} \"$(escape_double_quotation_marks "${arg}")\""
        ;;
      *)
        command="${command} $(escape_double_quotation_marks "${arg}")"
        ;;
    esac
  done
  print_s "${command}"
}

test_is_integer () {
  [ "$1" -eq "$1" ] 2> /dev/null
}

test_contains_double_quotation_mark() {
  local string="$1"
  print_s "$1" | grep "\"" > /dev/null
}

update_group_spec () {
  local create_user="$1"
  local gid_exists="$2"
  local group_name_exists="$3"
  local local_gid="$4"
  local local_group_name="$5"
  local quiet="$6"
  local return_gid="$7"
  local return_group_name="$8"
  local return_create_group="$9"
  local username="${10}"

  local local_create_group=

  if [ "${gid_exists}" -eq 0 ]; then
    local group_name_of_gid="$(getent group "${local_gid}" | awk -F ":" '{print $1}')"
    if [ -z "${quiet}" ] && [ ! -z "${local_group_name}" ] && [ "${local_group_name}" != "${group_name_of_gid}" ]; then
      print_warning "We have ignored the group name you specified, ${local_group_name}. The GID you specified, ${local_gid}, exists with the group name ${group_name_of_gid}."
    fi
    local_group_name="${group_name_of_gid}"
  elif [ "${group_name_exists}" -eq 0 ]; then
    if [ -z "${local_gid}" ]; then
      local gid_of_group_name="$(getent group "${local_group_name}" | awk -F ":" '{print $3}')"
      if [ -z "${quiet}" ] \
      && [ ! -z "${local_gid}" ] \
      && [ "${local_gid}" != "${gid_of_group_name}" ]; then
        print_warning "We have ignored the GID you specified, ${local_gid}. The group name you specified, ${local_group_name}, exists with the GID ${gid_of_group_name}."
      fi
      local_gid="${gid_of_group_name}"
    else
      local_group_name=
      local_create_group=0
    fi
  else
    if [ -z "${create_user}" ] \
    && [ -z "${local_gid}" ] \
    && [ -z "${local_group_name}" ]; then
      local_gid="$(id -g "${username}")"
      local_group_name="$(id -gn "${username}")"
    else
      local_create_group=0
    fi
  fi

  eval $return_gid="'${local_gid}'"
  eval $return_group_name="'${local_group_name}'"
  eval $return_create_group="'${local_create_group}'"
}

update_user_spec () {
  local local_uid="$1"
  local local_username="$2"
  local quiet="$3"
  local return_uid="$4"
  local return_username="$5"
  local return_create_user="$6"
  local uid_exists="$7"
  local username_exists="$8"

  local local_create_user

  if [ "${uid_exists}" -eq 0 ]; then
    # Using id with a UID does not work in Alpine Linux.
    local username_of_uid="$(getent passwd "${local_uid}" | awk -F ":" '{print $1}')"
    if [ -z "${quiet}" ] \
    && [ ! -z "${local_username}" ] \
    && [ "${local_username}" != "${username_of_uid}" ]; then
      print_warning "We have ignored the username you specified, ${local_username}. The UID you specified, ${local_uid}, exists with the username ${username_of_uid}."
    fi
    local_username="${username_of_uid}"
  elif [ "${username_exists}" -eq 0 ]; then
    if [ -z "${local_uid}" ]; then
      local uid_of_username="$(id -u "${local_username}")"
      if [ -z "${quiet}" ] \
      && [ ! -z "${local_uid}" ] \
      && [ "${local_uid}" != "${uid_of_username}" ]; then
        print_warning "We have ignored the UID you specified, ${local_uid}. The username you specified, ${local_username}, exists with the UID ${uid_of_username}."
      fi
      local_uid="${uid_of_username}"
    else
      local_username="nonroot"
      local_create_user=0
    fi
  else
    if [ -z "${local_username}" ]; then
      local_username="nonroot"
    fi
    local_create_user=0
  fi

  if [ "${local_create_user}" = "0" ] \
  && [ "${local_username}" = "nonroot" ]; then
    does_user_exist "nonroot"
    if [ "$?" -eq 0 ]; then
      local_uid="$(id -u nonroot)"
      local_create_user=
    fi
  fi

  eval $return_uid="'${local_uid}'"
  eval $return_username="'${local_username}'"
  eval $return_create_user="'${local_create_user}'"
}

yum_install_su_exec () {
  local debug="$1"
  local quiet="$2"

  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_nsn "$(output_cyan)Executing$(output_reset) yum install -y gcc make unzip ..."
  fi
  if [ -z "${quiet}" ]; then
    yum install -y gcc make unzip
  else
    yum install -y gcc make unzip > /dev/null 2>&1
  fi
  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_sn "$(output_cyan)DONE$(output_reset)"
  fi

  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_nsn "$(output_cyan)Executing$(output_reset) curl -L https://github.com/ncopa/su-exec/archive/dddd1567b7c76365e1e0aac561287975020a8fad.zip -o su-exec.zip ..."
  fi
  if [ -z "${quiet}" ]; then
    curl -L https://github.com/ncopa/su-exec/archive/dddd1567b7c76365e1e0aac561287975020a8fad.zip -o su-exec.zip
  else
    curl --silent -L https://github.com/ncopa/su-exec/archive/dddd1567b7c76365e1e0aac561287975020a8fad.zip -o su-exec.zip
  fi
  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_sn "$(output_cyan)DONE$(output_reset)"
  fi

  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_nsn "$(output_cyan)Installing$(output_reset) su-exec ..."
  fi
  if [ -z "${quiet}" ]; then
    unzip su-exec.zip
    cd su-exec-dddd1567b7c76365e1e0aac561287975020a8fad
    make
    mv su-exec /usr/local/bin
    cd ..
    rm -rf su-exec-dddd1567b7c76365e1e0aac561287975020a8fad
  else
    unzip su-exec.zip > /dev/null
    cd su-exec-dddd1567b7c76365e1e0aac561287975020a8fad
    make > /dev/null
    mv su-exec /usr/local/bin
    cd ..
    rm -rf su-exec-dddd1567b7c76365e1e0aac561287975020a8fad
  fi
  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_sn "$(output_cyan)DONE$(output_reset)"
  fi
}

yum_install_tini () {
  local debug="$1"
  local quiet="$2"

  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_nsn "$(output_cyan)Executing$(output_reset) curl -L https://github.com/krallin/tini/releases/download/v0.18.0/tini-static -o /usr/local/bin/tini ..."
  fi
  if [ -z "${quiet}" ]; then
    curl -L https://github.com/krallin/tini/releases/download/v0.18.0/tini-static -o /usr/local/bin/tini
  else
    curl --silent -L https://github.com/krallin/tini/releases/download/v0.18.0/tini-static -o /usr/local/bin/tini
  fi
  if [ "${debug}" = "y" ] || [ -z "${quiet}" ]; then
    print_sn "$(output_cyan)DONE$(output_reset)"
  fi

  chmod +x /usr/local/bin/tini
}

main "$@"
