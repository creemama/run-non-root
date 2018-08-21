#!/bin/sh

print_help () {
  echo "Usage:"
  echo "  run-non-root [options] [--] [COMMAND] [ARGS...]"
  echo
  echo "Options:"
  echo "  -d, --debug             Output debug information; using --quiet does not"
  echo "                          silence debug output."
  echo "  -f, --group GROUP_NAME  The group name to use when executing the command; the"
  echo "                          default group name is USERNAME or nonroot; this"
  echo "                          option is ignored if we are already running as a"
  echo "                          non-root user or if the GID already exists; this"
  echo "                          option overrides the RUN_NON_ROOT_GROUP_NAME"
  echo "                          environment variable."
  echo "  -g, --gid GID           The group ID to use when executing the command; the"
  echo "                          default GID is UID or a new ID determined by"
  echo "                          groupadd; this option is ignored if we are already"
  echo "                          running as a non-root user; this option overrides the"
  echo "                          RUN_NON_ROOT_GID environment variable."
  echo "  -h, --help              Output this help message and exit."
  echo "  -q, --quiet             Do not output \"Running ( COMMAND ) as USER_INFO ...\""
  echo "                          or warnings; this option does not silence --debug"
  echo "                          output."
  echo "  -t, --user USERNAME     The username to use when executing the command; the"
  echo "                          default is nonroot; this option is ignored if we are"
  echo "                          already running as a non-root user or if the UID"
  echo "                          already exists; this option overrides the"
  echo "                          RUN_NON_ROOT_USERNAME environment variable."
  echo "  -u, --uid UID           The user ID to use when executing the command; the"
  echo "                          default UID is GID or a new ID determined by"
  echo "                          useraddd; this option is ignored if we are already"
  echo "                          running as a non-root user; this option overrides the"
  echo "                          RUN_NON_ROOT_UID environment variable."
  echo
  echo "Environment Variables:"
  echo "  RUN_NON_ROOT_COMMAND    The command to execute if a command is not given; the"
  echo "                          default is sh."
  echo "  RUN_NON_ROOT_GID        The group ID to use when executing the command; see"
  echo "                          the --gid option for more info."
  echo "  RUN_NON_ROOT_GROUP      The group name to use when executing the command; see"
  echo "                          the --group option for more info."
  echo "  RUN_NON_ROOT_UID        The user ID to use when executing the command; see"
  echo "                          the --uid option for more info."
  echo "  RUN_NON_ROOT_USER       The username to use when executing the command; see"
  echo "                          the --user option for more info."
  echo
  echo "Examples:"
  echo "  # Run sh as a non-root user."
  echo "  run-non-root"
  echo
  echo "  # Run id as a non-root user."
  echo "  run-non-root -- id"
  echo
  echo "  # Run id as a non-root user using options and the given user specification."
  echo "  run-non-root -f ec2-user -g 1000 -t ec2-user -u 1000 -- id"
  echo
  echo "  # Run id as a non-root user using environment variables"
  echo "  # and the given user specification."
  echo "  export RUN_NON_ROOT_GID=1000"
  echo "  export RUN_NON_ROOT_GROUP_NAME=ec2-user"
  echo "  export RUN_NON_ROOT_UID=1000"
  echo "  export RUN_NON_ROOT_USERNAME=ec2-user"
  echo "  run-non-root -- id"
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
    if [ "${local_gid}" -eq "${local_gid}" ] 2> /dev/null; then
      echo > /dev/null 2>&1
    else
      exit_with_error 10 "We expected GID to be an integer, but it was ${local_gid}."
    fi
    gid_option="--gid ${local_gid}"
  fi

  check_for_groupadd "${debug}" "${quiet}"

  if [ ! -z "${debug}" ]; then
    printf "\n$(output_cyan)Executing$(output_reset) groupadd ${gid_option} \"${local_group_name}\" ... "
  fi
  # "groupadd(8) - Linux man page"
  # https://linux.die.net/man/8/groupadd
  # gid_option is unquoted.
  groupadd ${gid_option} "${local_group_name}"
  if [ "$?" -ne 0 ]; then
    local gid_part=
    if [ ! -z "${local_gid}" ]; then
      gid_part=" with ID ${local_gid}"
    fi
    exit_with_error 4 "We could not add the group ${local_group_name}${gid_part}."
  fi
  if [ ! -z "${debug}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi

  if [ -z "${local_gid}" ]; then
    local_gid="`getent group ${local_group_name} | awk -F ":" '{print $3}'`"
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
    if [ "${uid}" -eq "${uid}" ] 2> /dev/null; then
      echo > /dev/null 2>&1
    else
      exit_with_error 11 "We expected UID to be an integer, but it was ${uid}."
    fi
    uid_option="--uid ""${uid}"
  fi

  check_for_useradd "${debug}" "${quiet}"

  # In alpine:3.7, useradd set the shell to /bin/bash even though it doesn't exist.
  # As such, we set "--shell /bin/sh".
  if [ ! -z "${debug}" ]; then
    printf "\n$(output_cyan)Executing$(output_reset) useradd \\ \n"
    printf "  --create-home \\ \n"
    printf "  --gid \"${gid}\" \\ \n"
    printf "  --no-log-init \\ \n"
    printf "  --shell /bin/sh \\ \n"
    if [ ! -z "${uid_option}" ]; then
      printf "  ${uid_option} \\ \n"
    fi
    printf "  \"${username}\" ... "
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
    exit_with_error 7 "We could not add the user ${username} with ID ${uid}."
  fi
  if [ ! -z "${debug}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi
}

apk_add_shadow () {
  local debug="$1"
  local quiet="$2"
  if [ -z "${quiet}" ]; then
    print_warning "To speed up this command, call \"apk update && apk add shadow\" before executing this command."
  fi
  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    printf "\n$(output_cyan)Executing$(output_reset) apk update && apk add shadow ...\n"
  fi
  if [ -z "${quiet}" ]; then
    apk update && apk add shadow
  else
    apk update > /dev/null && apk add shadow > /dev/null
  fi
  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi
}

apk_add_su_exec () {
  local debug="$1"
  local quiet="$2"
  if [ -z "${quiet}" ]; then
    print_warning "To speed up this command, call \"apk update && apk add su-exec\" before executing this command."
  fi
  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    printf "\n$(output_cyan)Executing$(output_reset) apk update && apk add su-exec ...\n"
  fi
  if [ -z "${quiet}" ]; then
    apk update && apk add su-exec
  else
    apk update > /dev/null && apk add su-exec > /dev/null
  fi
  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi
}

apt_get_install_su_exec () {
  local debug="$1"
  local quiet="$2"

  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    printf "\n$(output_cyan)Executing$(output_reset) apt-get update ...\n"
  fi
  if [ -z "${quiet}" ]; then
    apt-get update
  else
    apt-get update > /dev/null 2>&1
  fi
  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi

  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    printf "\n$(output_cyan)Executing$(output_reset) apt-get install -y curl gcc make unzip ...\n"
  fi
  if [ -z "${quiet}" ]; then
    apt-get install -y curl gcc make unzip
  else
    apt-get install -y curl gcc make unzip > /dev/null 2>&1
  fi
  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi

  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    printf "\n$(output_cyan)Executing$(output_reset) curl -L https://github.com/ncopa/su-exec/archive/dddd1567b7c76365e1e0aac561287975020a8fad.zip -o su-exec.zip ...\n"
  fi
  if [ -z "${quiet}" ]; then
    curl -L https://github.com/ncopa/su-exec/archive/dddd1567b7c76365e1e0aac561287975020a8fad.zip -o su-exec.zip
  else
    curl --silent -L https://github.com/ncopa/su-exec/archive/dddd1567b7c76365e1e0aac561287975020a8fad.zip -o su-exec.zip
  fi
  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi

  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    printf "\n$(output_cyan)Installing$(output_reset) su-exec ...\n"
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
  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi
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
    if [ ! -z "${debug}" ]; then
      printf "\n$(output_cyan)Executing$(output_reset) mkdir -p /var/mail ... "
    fi
    mkdir -p /var/mail
    if [ ! -z "${debug}" ]; then
      printf "$(output_cyan)DONE$(output_reset)\n"
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

exit_with_error () {
  local exit_code="$1"
  local message="$2"
  (>&2 echo "$(output_red)$(output_bold)ERROR (${exit_code}):$(output_reset)$(output_red) ${message}$(output_reset)")
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

  # "How do I parse command line arguments in Bash?"
  # https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash

  check_for_getopt
  local parsed_options="`getopt \
    --options=df:g:hqt:u: \
    --longoptions=debug,gid:,group:,help,quiet,uid:,user: \
    --name "$0" \
    -- "$@"`"
  if [ "$?" -ne 0 ]; then
    exit 1
  fi
  eval set -- "${parsed_options}"

  local command="${RUN_NON_ROOT_COMMAND}"
  local debug=
  local gid="${RUN_NON_ROOT_GID}"
  local group_name="${RUN_NON_ROOT_GROUP_NAME}"
  local help=
  local quiet=
  local uid="${RUN_NON_ROOT_UID}"
  local username="${RUN_NON_ROOT_USERNAME}"

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
        help="y"
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
      --)
        shift
        break
        ;;
      *)
        exit_with_error 1 "There was an error processing options."
        ;;
    esac
  done

  # "How to use arguments like $1 $2 … in a for loop?"
  # https://unix.stackexchange.com/questions/314032/how-to-use-arguments-like-1-2-in-a-for-loop
  if [ ! -z "$1" ]; then
    command=$1
    shift
    for arg
      # "How to check if a string has spaces in Bash shell"
      # https://stackoverflow.com/questions/1473981/how-to-check-if-a-string-has-spaces-in-bash-shell
      do case "${arg}" in
        *\ *)
          command="${command} \"${arg}\""
          ;;
        *)
          command="${command} ${arg}"
          ;;
      esac
    done
  fi

  if [ ! -z "${debug}" ]; then
    echo
    echo "$(output_cyan)Command Options:$(output_reset)"
    echo "  $(output_cyan)command=$(output_reset)${command}"
    echo "  $(output_cyan)debug=$(output_reset)${debug}"
    echo "  $(output_cyan)gid=$(output_reset)${gid}"
    echo "  $(output_cyan)group_name=$(output_reset)${group_name}"
    echo "  $(output_cyan)help=$(output_reset)${help}"
    echo "  $(output_cyan)quiet=$(output_reset)${quiet}"
    echo "  $(output_cyan)uid=$(output_reset)${uid}"
    echo "  $(output_cyan)username=$(output_reset)${username}"
  fi

  if [ ! -z "${help}" ]; then
    print_help
    exit 0
  fi

  run_non_root \
    "${command}" \
    "${debug}" \
    "${gid}" \
    "${group_name}" \
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

print_exit_code () {
  local debug="$1"
  local exit_code="$2"
  local quiet="$3"
  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    if [ "${exit_code}" -eq 0 ]; then
      printf "\n$(output_green)Exit Code: ${exit_code}$(output_reset)\n\n"
    else
      printf "\n$(output_red)Exit Code: ${exit_code}$(output_reset)\n\n"
    fi
  fi
}

print_warning () {
  printf "\n$(output_yellow)$(output_bold)WARNING:$(output_reset)$(output_yellow) $1$(output_reset)\n"
}

run_as_current_user () {
  local command="${1:-sh}"
  local quiet="$2"
  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    print_warning "You are already running as a non-root user. We have ignored all group and user options."
    printf "\n$(output_green)Running ( $(output_bold)${command}$(output_reset)$(output_green) ) as $(id) ...\n\n$(output_reset)"
  fi
  # command is unquoted.
  exec ${command}
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
  local quiet="$5"
  local uid="$6"
  local username="$7"

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

  check_for_su_exec "${debug}" "${quiet}"
  if [ ! -z "${debug}" ] || [ -z ${quiet} ]; then
    printf "\n$(output_green)Running ( su-exec \"${username}:${gid}\" $(output_bold)${command}$(output_reset)$(output_green) ) as $(id ${username}) ...\n\n$(output_reset)"
  fi
  # command is unquoted.
  exec su-exec "${username}:${gid}" ${command}
}

run_non_root () {
  local command="$1"
  local debug="$2"
  local gid="$3"
  local group_name="$4"
  local quiet="$5"
  local uid="$6"
  local username="$7"

  if [ "$(whoami)" = "root" ]; then
    run_as_non_root_user \
      "${command}" \
      "${debug}" \
      "${gid}" \
      "${group_name}" \
      "${quiet}" \
      "${uid}" \
      "${username}"
  else
    run_as_current_user "${command}" "${quiet}"
  fi
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
    local group_name_of_gid="`getent group "${local_gid}" | awk -F ":" '{print $1}'`"
    if [ -z "${quiet}" ] && [ ! -z "${local_group_name}" ] && [ "${local_group_name}" != "${group_name_of_gid}" ]; then
      print_warning "We have ignored the group name you specified, ${local_group_name}. The GID you specified, ${local_gid}, exists with the group name ${group_name_of_gid}."
    fi
    local_group_name="${group_name_of_gid}"
  elif [ "${group_name_exists}" -eq 0 ]; then
    if [ -z "${local_gid}" ]; then
      local gid_of_group_name="`getent group "${local_group_name}" | awk -F ":" '{print $3}'`"
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
      local_gid="`id -g "${username}"`"
      local_group_name="`id -gn "${username}"`"
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
    local username_of_uid="`getent passwd "${local_uid}" | awk -F ":" '{print $1}'`"
    if [ -z "${quiet}" ] \
    && [ ! -z "${local_username}" ] \
    && [ "${local_username}" != "${username_of_uid}" ]; then
      print_warning "We have ignored the username you specified, ${local_username}. The UID you specified, ${local_uid}, exists with the username ${username_of_uid}."
    fi
    local_username="${username_of_uid}"
  elif [ "${username_exists}" -eq 0 ]; then
    if [ -z "${local_uid}" ]; then
      local uid_of_username="`id -u "${local_username}"`"
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

  eval $return_uid="'${local_uid}'"
  eval $return_username="'${local_username}'"
  eval $return_create_user="'${local_create_user}'"
}

yum_install_su_exec () {
  local debug="$1"
  local quiet="$2"

  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    printf "\n$(output_cyan)Executing$(output_reset) yum install -y gcc make unzip ...\n"
  fi
  if [ -z "${quiet}" ]; then
    yum install -y gcc make unzip
  else
    yum install -y gcc make unzip > /dev/null 2>&1
  fi
  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi

  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    printf "\n$(output_cyan)Executing$(output_reset) curl -L https://github.com/ncopa/su-exec/archive/dddd1567b7c76365e1e0aac561287975020a8fad.zip -o su-exec.zip ...\n"
  fi
  if [ -z "${quiet}" ]; then
    curl -L https://github.com/ncopa/su-exec/archive/dddd1567b7c76365e1e0aac561287975020a8fad.zip -o su-exec.zip
  else
    curl --silent -L https://github.com/ncopa/su-exec/archive/dddd1567b7c76365e1e0aac561287975020a8fad.zip -o su-exec.zip
  fi
  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi

  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    printf "\n$(output_cyan)Installing$(output_reset) su-exec ...\n"
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
  if [ ! -z "${debug}" ] || [ -z "${quiet}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi
}

main "$@"
