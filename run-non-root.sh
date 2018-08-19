#!/bin/sh

print_help () {
  echo "Usage:"
  echo "  run-non-root [options] [--] [COMMAND] [ARGS...]"
  echo
  echo "Options:"
  echo "  -d, --debug              Output debug information; using --quiet does not"
  echo "                           silence debug output."
  echo "  -f, --gname GROUP_NAME   The group name to use when executing the command;"
  echo "                           the default is nonrootgroup; this option is ignored"
  echo "                           if we are already running as a non-root user; when"
  echo "                           specified, this option overrides the"
  echo "                           RUN_NON_ROOT_GROUP_NAME environment variable."
  echo "  -g, --gid GROUP_ID       The group ID to use when executing the command;"
  echo "                           the default is the first unused group ID strictly"
  echo "                           less than 1000; this option is ignored if we are"
  echo "                           already running as a non-root user; when specified,"
  echo "                           this option overrides the RUN_NON_ROOT_GROUP_ID"
  echo "                           environment variable."
  echo "  -h, --help               Output this help message and exit."
  echo "  -q, --quiet              Do not output \"Running ( COMMAND ) as USER_INFO ...\""
  echo "                           or warnings; this option does not silence --debug"
  echo "                           output."
  echo "  -t, --uname USER_NAME    The user name to use when executing the command;"
  echo "                           the default is nonrootuser; this option is ignored"
  echo "                           if we are already running as a non-root user; when"
  echo "                           specified, this option overrides the"
  echo "                           RUN_NON_ROOT_USER_NAME environment variable."
  echo "  -u, --uid USER_ID        The user ID to use when executing the command;"
  echo "                           the default is the first unused user ID strictly"
  echo "                           less than 1000; this option is ignored if we are"
  echo "                           already running as a non-root user; when specified,"
  echo "                           this option overrides the RUN_NON_ROOT_USER_ID"
  echo "                           environment variable."
  echo
  echo "Environment Variables:"
  echo "  RUN_NON_ROOT_COMMAND     The command to execute if a command is not given;"
  echo "                           the default is sh."
  echo "  RUN_NON_ROOT_GROUP_ID    The group ID to use when executing the command; the"
  echo "                           default is the first unused group ID strictly less"
  echo "                           than 1000; this variable is ignored if we are"
  echo "                           already running as a non-root user; the -g and --gid"
  echo "                           options override this environment variable."
  echo "  RUN_NON_ROOT_GROUP_NAME  The user name to use when executing the command; the"
  echo "                           default is nonrootgroup; this variable is ignored if"
  echo "                           we are already running as a non-root user; the -f"
  echo "                           and --gname options override this environment"
  echo "                           variable."
  echo "  RUN_NON_ROOT_USER_ID     The user ID to use when executing the command; the"
  echo "                           default is the first unused user ID strictly less"
  echo "                           than 1000; this variable is ignored if we are"
  echo "                           already running as a non-root user; the -u and --uid"
  echo "                           options override this environment variable."
  echo "  RUN_NON_ROOT_USER_NAME   The user name to use when executing the command; the"
  echo "                           default is nonrootuser; this option is ignored if we"
  echo "                           are already running as a non-root user; the -t and"
  echo "                           --uname options override this environment variable."
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
  echo "  export RUN_NON_ROOT_GROUP_ID=1000"
  echo "  export RUN_NON_ROOT_GROUP_NAME=ec2-user"
  echo "  export RUN_NON_ROOT_USER_ID=1000"
  echo "  export RUN_NON_ROOT_USER_NAME=ec2-user"
  echo "  run-non-root -- id"
}

apk_add_shadow () {
  local DEBUG=$1
  local QUIET=$2
  if [ -z "${QUIET}" ]; then
    print_warning "To speed up this command, call \"apk update && apk add shadow\" before executing this command."
  fi
  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "\n$(output_cyan)Executing$(output_reset) apk update && apk add shadow ...\n"
  fi
  if [ -z "${QUIET}" ]; then
    apk update && apk add shadow
  else
    apk update > /dev/null && apk add shadow > /dev/null
  fi
  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi
}

apk_add_su_exec () {
  local DEBUG=$1
  local QUIET=$2
  if [ -z "${QUIET}" ]; then
    print_warning "To speed up this command, call \"apk update && apk add su-exec\" before executing this command."
  fi
  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "\n$(output_cyan)Executing$(output_reset) apk update && apk add su-exec ...\n"
  fi
  if [ -z "${QUIET}" ]; then
    apk update && apk add su-exec
  else
    apk update > /dev/null && apk add su-exec > /dev/null
  fi
  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi
}

apt_get_install_su_exec () {
  local DEBUG=$1
  local QUIET=$2

  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "\n$(output_cyan)Executing$(output_reset) apt-get update ...\n"
  fi
  if [ -z "${QUIET}" ]; then
    apt-get update
  else
    apt-get update > /dev/null 2>&1
  fi
  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi

  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "\n$(output_cyan)Executing$(output_reset) apt-get install -y curl gcc make unzip ...\n"
  fi
  if [ -z "${QUIET}" ]; then
    apt-get install -y curl gcc make unzip
  else
    apt-get install -y curl gcc make unzip > /dev/null 2>&1
  fi
  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi

  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "\n$(output_cyan)Executing$(output_reset) curl -L https://github.com/ncopa/su-exec/archive/dddd1567b7c76365e1e0aac561287975020a8fad.zip -o su-exec.zip ...\n"
  fi
  if [ -z "${QUIET}" ]; then
    curl -L https://github.com/ncopa/su-exec/archive/dddd1567b7c76365e1e0aac561287975020a8fad.zip -o su-exec.zip
  else
    curl --silent -L https://github.com/ncopa/su-exec/archive/dddd1567b7c76365e1e0aac561287975020a8fad.zip -o su-exec.zip
  fi
  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi

  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "\n$(output_cyan)Installing$(output_reset) su-exec ...\n"
  fi
  if [ -z "${QUIET}" ]; then
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
  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi
}

check_for_getopt () {
  command -v getopt > /dev/null
  if [ $? -ne 0 ]; then
    command -v yum > /dev/null
    if [ $? -eq 0 ]; then
      yum install -y util-linux-ng > /dev/null 2>&1
    fi
  fi
}

check_for_groupadd () {
  local DEBUG=$1
  local QUIET=$2
  command -v groupadd > /dev/null
  if [ $? -ne 0 ]; then
    command -v apk > /dev/null
    if [ $? -eq 0 ]; then
      apk_add_shadow "${DEBUG}" "${QUIET}"
    fi
  fi
}

check_for_useradd () {
  local DEBUG=$1
  local QUIET=$2
  command -v useradd > /dev/null
  if [ $? -ne 0 ]; then
    command -v apk > /dev/null
    if [ $? -eq 0 ]; then
      apk_add_shadow "${DEBUG}" "${QUIET}"
    fi
  fi
  command -v apk > /dev/null
  if [ $? -eq 0 ]; then
    # In alpine:3.7, unless we execute the following command, we get the
    # following error after calling useradd:
    # Creating mailbox file: No such file or directory
    if [ ! -z "${DEBUG}" ]; then
      printf "\n$(output_cyan)Executing$(output_reset) mkdir -p /var/mail ... "
    fi
    mkdir -p /var/mail
    if [ ! -z "${DEBUG}" ]; then
      printf "$(output_cyan)DONE$(output_reset)\n"
    fi
  fi
}

check_for_su_exec () {
  local DEBUG=$1
  local QUIET=$2
  command -v su-exec > /dev/null
  if [ $? -ne 0 ]; then

    # "Package Management Basics: apt, yum, dnf, pkg"
    # https://www.digitalocean.com/community/tutorials/package-management-basics-apt-yum-dnf-pkg.

    command -v apk > /dev/null
    if [ $? -eq 0 ]; then
      apk_add_su_exec "${DEBUG}" "${QUIET}"
      return $?
    fi
    command -v apt-get > /dev/null
    if [ $? -eq 0 ]; then
      apt_get_install_su_exec "${DEBUG}" "${QUIET}"
      return $?
    fi
    command -v yum > /dev/null
    if [ $? -eq 0 ]; then
      yum_install_su_exec "${DEBUG}" "${QUIET}"
      return $?
    fi
  fi
}

determine_group_id () {
  local RETURN_VALUE=$1
  local DEBUG=$2
  # The eval at the end does not work if we use GROUP_ID.
  local LOCAL_GROUP_ID=$3
  local GROUP_NAME=$4
  local QUIET=$5
  local USER_ID=$6
  local USER_NAME=$7

  exists_group_id "${LOCAL_GROUP_ID}"
  local GROUP_ID_EXISTS=$?

  getent group "${GROUP_NAME}" > /dev/null 2>&1
  local GROUP_NAME_EXISTS=$?

  exists_user_id "${USER_ID}"
  local USER_ID_EXISTS=$?

  getent passwd "${USER_NAME}" > /dev/null 2>&1
  local USER_NAME_EXISTS=$?

  if [ "${GROUP_ID_EXISTS}" -ne 0 ] && [ "${GROUP_NAME_EXISTS}" -ne 0 ]; then
    if [ "${USER_ID_EXISTS}" -ne 0 ] && [ "${USER_NAME_EXISTS}" -ne 0 ]; then
      # Find a group ID that does not exist starting from 999.
      if [ -z "${LOCAL_GROUP_ID}" ]; then
        find_unused_group_id LOCAL_GROUP_ID
      fi
      check_for_groupadd "${DEBUG}" "${QUIET}"
      if [ ! -z "${DEBUG}" ]; then
        printf "\n$(output_cyan)Executing$(output_reset) groupadd --gid \"${LOCAL_GROUP_ID}\" \"${GROUP_NAME}\" ... "
      fi
      groupadd --gid "${LOCAL_GROUP_ID}" "${GROUP_NAME}"
      if [ $? -ne 0 ]; then
        exit_with_error 4 "We could not add the group ${GROUP_NAME} with ID ${LOCAL_GROUP_ID}."
      fi
      if [ ! -z "${DEBUG}" ]; then
        printf "$(output_cyan)DONE$(output_reset)\n"
      fi
    elif [ "${USER_ID_EXISTS}" -ne 0 ]; then
      LOCAL_GROUP_ID=`id -g ${USER_NAME}`
    else
      # Using id with a UID does not work in Alpine Linux.
      LOCAL_GROUP_ID=`getent passwd ${USER_ID} | awk -F ":" '{print $4}'`
    fi
  elif [ "${GROUP_ID_EXISTS}" -ne 0 ]; then
    LOCAL_GROUP_ID=`getent group ${GROUP_NAME} | awk -F ":" '{print $3}'`
  fi

  eval $RETURN_VALUE="'${LOCAL_GROUP_ID}'"
}

determine_user_name () {
  local RETURN_VALUE=$1
  local DEBUG=$2
  local GROUP_ID=$3
  local QUIET=$4
  local USER_ID=$5
  # The eval at the end (might) not work if we use USER_NAME.
  # See determine_group_id and its LOCAL_GROUP_ID.
  local LOCAL_USER_NAME=$6

  exists_user_id "${USER_ID}"
  local USER_ID_EXISTS=$?

  getent passwd "${LOCAL_USER_NAME}" > /dev/null 2>&1
  local USER_NAME_EXISTS=$?

  if [ "${USER_ID_EXISTS}" -ne 0 ] && [ "${USER_NAME_EXISTS}" -ne 0 ]; then
    # Find a user ID that does not exist starting from 999.
    if [ -z "${USER_ID}" ]; then
      find_unused_user_id USER_ID
    fi
    check_for_useradd "${DEBUG}" "${QUIET}"
    # In alpine:3.7, useradd set the shell to /bin/bash even though it doesn't exist.
    # As such, we set "--shell sh".
    if [ ! -z "${DEBUG}" ]; then
      printf "\n$(output_cyan)Executing$(output_reset) useradd \\ \n"
      printf "  --create-home \\ \n"
      printf "  --gid \"${GROUP_ID}\" \\ \n"
      printf "  --no-log-init \\ \n"
      printf "  --shell /bin/sh \\ \n"
      printf "  --uid \"${USER_ID}\" \\ \n"
      printf "  \"${LOCAL_USER_NAME}\" ... "
    fi
    useradd \
      --create-home \
      --gid "${GROUP_ID}" \
      --no-log-init \
      --shell /bin/sh \
      --uid "${USER_ID}" \
      "${LOCAL_USER_NAME}"
    if [ $? -ne 0 ]; then
      exit_with_error 7 "We could not add the user ${LOCAL_USER_NAME} with ID ${USER_ID}."
    fi
    if [ ! -z "${DEBUG}" ]; then
      printf "$(output_cyan)DONE$(output_reset)\n"
    fi
  elif [ "${USER_ID_EXISTS}" -ne 0 ]; then
    USER_ID=`id -u ${LOCAL_USER_NAME}`
  else
    # Using id with a UID does not work in Alpine Linux.
    LOCAL_USER_NAME=`getent passwd ${USER_ID} | awk -F ":" '{print $1}'`
  fi

  eval $RETURN_VALUE="'${LOCAL_USER_NAME}'"
}

exists_group_id () {
  local GROUP_ID=$1
  if [ -z "${GROUP_ID}" ]; then
    return 1
  else
    getent group "${GROUP_ID}" > /dev/null 2>&1
  fi
}

exists_user_id () {
  local USER_ID=$1
  if [ -z "${USER_ID}" ]; then
    return 1
  else
    getent passwd "${USER_ID}" > /dev/null 2>&1
  fi
}

exit_with_error () {
  local EXIT_CODE=$1
  local MESSAGE=$2
  (>&2 echo "$(output_red)$(output_bold)ERROR (${EXIT_CODE}):$(output_reset)$(output_red) ${MESSAGE}$(output_reset)")
  exit ${EXIT_CODE}
}

find_unused_group_id () {
  local RETURN_VALUE=$1
  local ID=999
  local UNUSED_GROUP_ID
  while [ -z "${UNUSED_GROUP_ID}" ] && [ "$ID" -gt 0 ]; do
    getent group "${ID}" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      UNUSED_GROUP_ID="${ID}"
    fi
    ID=$((ID-1))
  done
  if [ "$ID" -eq 0 ]; then
    exit_with_error 3 "We could not find an unused group ID strictly greater than 0 and strictly less than 1000."
  fi
  eval $RETURN_VALUE="'${UNUSED_GROUP_ID}'"
}

find_unused_user_id () {
  local RETURN_VALUE=$1
  local ID=999
  local UNUSED_USER_ID
  while [ -z "${UNUSED_USER_ID}" ] && [ "$ID" -gt 0 ]; do
    getent passwd "${ID}" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      UNUSED_USER_ID="${ID}"
    fi
    ID=$((ID-1))
  done
  if [ "$ID" -eq 0 ]; then
    exit_with_error 6 "We could not find an unused user ID strictly greater than 0 and strictly less than 1000."
  fi
  eval $RETURN_VALUE="'${UNUSED_USER_ID}'"
}

local_tput () {
  # "No value for $TERM and no -T specified"
  # https://askubuntu.com/questions/591937/no-value-for-term-and-no-t-specified
  tty -s > /dev/null 2>&1
  if [ ! $? -eq 0 ]; then
    return 0
  fi
  command -v tput > /dev/null 2>&1
  if [ $? -eq 0 ]; then
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

output_yellow () {
  local_tput setaf 3
}

print_exit_code () {
  local DEBUG=$1
  local EXIT_CODE=$2
  local QUIET=$3
  if [ ! -z "${DEBUG}" ] || [ -z ${QUIET} ]; then
    if [ "${EXIT_CODE}" -eq 0 ]; then
      printf "\n$(output_green)Exit Code: ${EXIT_CODE}$(output_reset)\n\n"
    else
      printf "\n$(output_red)Exit Code: ${EXIT_CODE}$(output_reset)\n\n"
    fi
  fi
}

print_warning () {
  printf "\n$(output_yellow)$(output_bold)WARNING:$(output_reset)$(output_yellow) $1$(output_reset)\n"
}

run_as_current_user () {
  local COMMAND=${1:-sh}
  local QUIET=$2
  if [ ! -z "${DEBUG}" ] || [ -z ${QUIET} ]; then
    print_warning "You are already running as a non-root user. We have ignored all group and user options."
    printf "\n$(output_green)Running ( $(output_bold)${COMMAND}$(output_reset)$(output_green) ) as $(id) ...\n\n$(output_reset)"
  fi
  exec ${COMMAND}
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

  local COMMAND=${1:-sh}
  local DEBUG=$2
  local GROUP_ID=$3
  local GROUP_NAME=${4:-nonrootgroup}
  local QUIET=$5
  local USER_ID=$6
  local USER_NAME=${7:-nonrootuser}

  # "Returning Values from Bash Functions"
  # https://www.linuxjournal.com/content/return-values-bash-functions

  determine_group_id \
    GROUP_ID \
    "${DEBUG}" \
    "${GROUP_ID}" \
    "${GROUP_NAME}" \
    "${QUIET}" \
    "${USER_ID}" \
    "${USER_NAME}"
  determine_user_name \
    USER_NAME \
    "${DEBUG}" \
    "${GROUP_ID}" \
    "${QUIET}" \
    "${USER_ID}" \
    "${USER_NAME}"

  check_for_su_exec "${DEBUG}" "${QUIET}"
  if [ ! -z "${DEBUG}" ] || [ -z ${QUIET} ]; then
    printf "\n$(output_green)Running ( su-exec \"${USER_NAME}:${GROUP_ID}\" $(output_bold)${COMMAND}$(output_reset)$(output_green) ) as $(id ${USER_NAME}) ...\n\n$(output_reset)"
  fi
  exec su-exec "${USER_NAME}:${GROUP_ID}" ${COMMAND}
}

run_non_root () {
  local COMMAND=$1
  local DEBUG=$2
  local GROUP_ID=$3
  local GROUP_NAME=$4
  local QUIET=$5
  local USER_ID=$6
  local USER_NAME=$7

  if [ "$(whoami)" = "root" ]; then
    run_as_non_root_user \
      "${COMMAND}" \
      "${DEBUG}" \
      "${GROUP_ID}" \
      "${GROUP_NAME}" \
      "${QUIET}" \
      "${USER_ID}" \
      "${USER_NAME}"
  else
    run_as_current_user "${COMMAND}" "${QUIET}"
  fi
}

yum_install_su_exec () {
  local DEBUG=$1
  local QUIET=$2

  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "\n$(output_cyan)Executing$(output_reset) yum install -y gcc make unzip ...\n"
  fi
  if [ -z "${QUIET}" ]; then
    yum install -y gcc make unzip
  else
    yum install -y gcc make unzip > /dev/null 2>&1
  fi
  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi

  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "\n$(output_cyan)Executing$(output_reset) curl -L https://github.com/ncopa/su-exec/archive/dddd1567b7c76365e1e0aac561287975020a8fad.zip -o su-exec.zip ...\n"
  fi
  if [ -z "${QUIET}" ]; then
    curl -L https://github.com/ncopa/su-exec/archive/dddd1567b7c76365e1e0aac561287975020a8fad.zip -o su-exec.zip
  else
    curl --silent -L https://github.com/ncopa/su-exec/archive/dddd1567b7c76365e1e0aac561287975020a8fad.zip -o su-exec.zip
  fi
  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi

  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "\n$(output_cyan)Installing$(output_reset) su-exec ...\n"
  fi
  if [ -z "${QUIET}" ]; then
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
  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi
}

# "How do I parse command line arguments in Bash?"
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash

check_for_getopt
RUN_NON_ROOT_PARSED_OPTIONS=`getopt --options=df:g:hqt:u: --longoptions=debug,gid:,gname:,help,quiet,uid:,uname: --name "$0" -- "$@"`
if [ $? -ne 0 ]; then
  exit 1
fi
eval set -- "${RUN_NON_ROOT_PARSED_OPTIONS}"

RUN_NON_ROOT_COMMAND=${RUN_NON_ROOT_COMMAND}
RUN_NON_ROOT_DEBUG=${RUN_NON_ROOT_DEBUG}
RUN_NON_ROOT_GROUP_ID=${RUN_NON_ROOT_GROUP_ID}
RUN_NON_ROOT_GROUP_NAME=${RUN_NON_ROOT_GROUP_NAME}
RUN_NON_ROOT_HELP=${RUN_NON_ROOT_HELP}
RUN_NON_ROOT_QUIET=
RUN_NON_ROOT_USER_ID=${RUN_NON_ROOT_USER_ID}
RUN_NON_ROOT_USER_NAME=${RUN_NON_ROOT_USER_NAME}

while true; do
  case "$1" in
    -d|--debug)
      RUN_NON_ROOT_DEBUG=y
      shift
      ;;
    -f|--gname)
      RUN_NON_ROOT_GROUP_NAME="$2"
      shift 2
      ;;
    -g|--gid)
      RUN_NON_ROOT_GROUP_ID="$2"
      shift 2
      ;;
    -h|--help)
      RUN_NON_ROOT_HELP=y
      shift
      ;;
    -q|--quiet)
      RUN_NON_ROOT_QUIET=y
      shift
      ;;
    -t|--uname)
      RUN_NON_ROOT_USER_NAME="$2"
      shift 2
      ;;
    -u|--uid)
      RUN_NON_ROOT_USER_ID="$2"
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

RUN_NON_ROOT_COMMAND="$@"

if [ ! -z "${RUN_NON_ROOT_DEBUG}" ]; then
  echo
  echo "$(output_cyan)Command Options:$(output_reset)"
  echo "  $(output_cyan)RUN_NON_ROOT_COMMAND=$(output_reset)${RUN_NON_ROOT_COMMAND}"
  echo "  $(output_cyan)RUN_NON_ROOT_DEBUG=$(output_reset)${RUN_NON_ROOT_DEBUG}"
  echo "  $(output_cyan)RUN_NON_ROOT_GROUP_ID=$(output_reset)${RUN_NON_ROOT_GROUP_ID}"
  echo "  $(output_cyan)RUN_NON_ROOT_GROUP_NAME=$(output_reset)${RUN_NON_ROOT_GROUP_NAME}"
  echo "  $(output_cyan)RUN_NON_ROOT_HELP=$(output_reset)${RUN_NON_ROOT_HELP}"
  echo "  $(output_cyan)RUN_NON_ROOT_QUIET=$(output_reset)${RUN_NON_ROOT_QUIET}"
  echo "  $(output_cyan)RUN_NON_ROOT_USER_ID=$(output_reset)${RUN_NON_ROOT_USER_ID}"
  echo "  $(output_cyan)RUN_NON_ROOT_USER_NAME=$(output_reset)${RUN_NON_ROOT_USER_NAME}"
fi

if [ ! -z ${RUN_NON_ROOT_HELP} ]; then
  print_help
  exit 0
fi

run_non_root \
  "${RUN_NON_ROOT_COMMAND}" \
  "${RUN_NON_ROOT_DEBUG}" \
  "${RUN_NON_ROOT_GROUP_ID}" \
  "${RUN_NON_ROOT_GROUP_NAME}" \
  "${RUN_NON_ROOT_QUIET}" \
  "${RUN_NON_ROOT_USER_ID}" \
  "${RUN_NON_ROOT_USER_NAME}"
