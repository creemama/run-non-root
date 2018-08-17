#!/bin/sh

function print_help() {
  echo "Run a command as a non-root user, creating a non-root user if necessary."
  echo
  echo "Usage:"
  echo "  run-non-root [options] [--] [COMMAND] [ARGS...]"
  echo
  echo "Options:"
  echo "  -d, --debug              Output debug information;"
  echo "                           using --quiet does not silence debug output."
  echo "  -f, --gname GROUP_NAME   The group name to use when executing the command;"
  echo "                           the default is non-root-group;"
  echo "                           when specified, this option overrides the "
  echo "                           RUN_NON_ROOT_GROUP_NAME environment variable."
  echo "  -g, --gid GROUP_ID       The group ID to use when executing the command;"
  echo "                           the default is the first unused group ID"
  echo "                           strictly less than 1000;"
  echo "                           when specified, this option overrides the "
  echo "                           RUN_NON_ROOT_GROUP_ID environment variable."
  echo "  -h, --help               Output this help message and exit."
  echo "  -q, --quiet              Do not output \"Running COMMAND as USER_INFO ...\""
  echo "                           or warnings; this option does not silence debug output."
  echo "  -t, --uname USER_NAME    The user name to use when executing the command;"
  echo "                           the default is non-root-user;"
  echo "                           when specified, this option overrides the "
  echo "                           RUN_NON_ROOT_USER_NAME environment variable."
  echo "  -u, --uid USER_ID        The user ID to use when executing the command;"
  echo "                           the default is the first unused user ID"
  echo "                           strictly less than 1000;"
  echo "                           when specified, this option overrides the "
  echo "                           RUN_NON_ROOT_USER_ID environment variable."
  echo
  echo "Environment Variables:"
  echo "  RUN_NON_ROOT_COMMAND     The command to execute if a command is not given;"
  echo "                           the default is sh."
  echo "  RUN_NON_ROOT_GROUP_ID    The group ID to use when executing the command;"
  echo "                           the default is the first unused group ID"
  echo "                           strictly less than 1000;"
  echo "                           the -g or --gid options override this environment variable."
  echo "  RUN_NON_ROOT_GROUP_NAME  The user name to use when executing the command;"
  echo "                           the default is non-root-group;"
  echo "                           the -f or --gname options override this environment variable."
  echo "  RUN_NON_ROOT_USER_ID     The user ID to use when executing the command;"
  echo "                           the default is the first unused user ID"
  echo "                           strictly less than 1000;"
  echo "                           the -u or --uid options override this environment variable."
  echo "  RUN_NON_ROOT_USER_NAME   The user name to use when executing the command;"
  echo "                           the default is non-root-user;"
  echo "                           the -t or --uname options override this environment variable."
}

function apk_add_shadow() {
  local DEBUG=$1
  local QUIET=$2
  if [ -z "${QUIET}" ]; then
    print_warning "To speed up this command, call \"apk update && apk add shadow=4.5-r0\" before executing this command."
  fi
  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "\n$(output_cyan)Executing$(output_reset) apk update && apk add shadow=4.5-r0 ...\n"
  fi
  if [ -z "${QUIET}" ]; then
    apk update && apk add shadow=4.5-r0
  else
    apk update > /dev/null && apk add shadow=4.5-r0 > /dev/null
  fi
  if [ ! -z "${DEBUG}" ] || [ -z "${QUIET}" ]; then
    printf "$(output_cyan)DONE$(output_reset)\n"
  fi
}

function check_for_groupadd() {
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

function check_for_useradd() {
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

function determine_group_id() {
  local RETURN_VALUE=$1
  local DEBUG=$2
  # The eval at the end does not work if we use GROUP_ID.
  local LOCAL_GROUP_ID=$3
  local GROUP_NAME=$4
  local QUIET=$5

  exists_group_id "${LOCAL_GROUP_ID}"
  local GROUP_ID_EXISTS=$?

  getent group "${GROUP_NAME}" &> /dev/null
  local GROUP_NAME_EXISTS=$?

  if [ "${GROUP_ID_EXISTS}" -ne 0 ] && [ "${GROUP_NAME_EXISTS}" -ne 0 ]; then
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
  elif [ "${GROUP_ID_EXISTS}" -ne 0 ]; then
    LOCAL_GROUP_ID=`getent group ${GROUP_NAME} | awk -F ":" '{print $3}'`
  fi

  eval $RETURN_VALUE="'${LOCAL_GROUP_ID}'"
}

function determine_user_name() {
  local RETURN_VALUE=$1
  local DEBUG=$2
  local USER_ID=$3
  # The eval at the end (might) not work if we use USER_NAME.
  # See determine_group_id and its LOCAL_GROUP_ID.
  local LOCAL_USER_NAME=$4
  local GROUP_ID=$5
  local QUIET=$6

  exists_user_id "${USER_ID}"
  local USER_ID_EXISTS=$?

  getent passwd "${LOCAL_USER_NAME}" &> /dev/null
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
      printf "\n$(output_cyan)Executing$(output_reset) useradd\n"
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
    LOCAL_USER_NAME=`getent passwd ${USER_ID} | awk -F ":" '{print $1}'`
  fi

  eval $RETURN_VALUE="'${LOCAL_USER_NAME}'"
}

function exists_group_id() {
  local GROUP_ID=$1
  if [ -z "${GROUP_ID}" ]; then
    return 1
  else
    getent group "${GROUP_ID}" &> /dev/null
  fi
}

function exists_user_id() {
  local USER_ID=$1
  if [ -z "${USER_ID}" ]; then
    return 1
  else
    getent passwd "${USER_ID}" &> /dev/null
  fi
}

function exit_with_error() {
  local EXIT_CODE=$1
  local MESSAGE=$2
  (>&2 echo "$(output_red)$(output_bold)ERROR (${EXIT_CODE}):$(output_reset)$(output_red) ${MESSAGE}$(output_reset)")
  exit ${EXIT_CODE}
}

function find_unused_group_id() {
  local RETURN_VALUE=$1
  local ID=999
  local UNUSED_GROUP_ID
  while [ -z "${UNUSED_GROUP_ID}" ] && [ "$ID" -gt 0 ]; do
    getent group "${ID}" &> /dev/null
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

function find_unused_user_id() {
  local RETURN_VALUE=$1
  local ID=999
  local UNUSED_USER_ID
  while [ -z "${UNUSED_USER_ID}" ] && [ "$ID" -gt 0 ]; do
    getent passwd "${ID}" &> /dev/null
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

function local_tput() {
  type tput &> /dev/null
  if [ $? -eq 0 ]; then
    tput $@
  fi
}

function output_bold() {
  local_tput bold
}

function output_cyan() {
  local_tput setaf 6
}

function output_green() {
  local_tput setaf 2
}

function output_red() {
  local_tput setaf 1
}

function output_reset() {
  local_tput sgr0
}

function output_yellow() {
  local_tput setaf 3
}

function print_exit_code() {
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

function print_warning() {
  printf "\n$(output_yellow)$(output_bold)WARNING:$(output_reset)$(output_yellow) $1$(output_reset)\n"
}

function run_as_current_user() {
  local COMMAND=${1:-sh}
  local QUIET=$2
  if [ ! -z "${DEBUG}" ] || [ -z ${QUIET} ]; then
    printf "\n$(output_green)Running $(output_bold)${COMMAND}$(output_reset)$(output_green) as $(id $(id -nu)) ...\n\n$(output_reset)"
  fi
  eval "${COMMAND}"
  local EXIT_CODE=$?
  print_exit_code "${DEBUG}" "${EXIT_CODE}" "${QUIET}"
  exit ${EXIT_CODE}
}

function run_as_non_root_user() {

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
  local GROUP_NAME=${4:-non-root-group}
  local QUIET=$5
  local USER_ID=$6
  local USER_NAME=${7:-non-root-user}

  # "Returning Values from Bash Functions"
  # https://www.linuxjournal.com/content/return-values-bash-functions

  determine_group_id GROUP_ID "${DEBUG}" "${GROUP_ID}" "${GROUP_NAME}" "${QUIET}"
  determine_user_name USER_NAME "${DEBUG}" "${USER_ID}" "${USER_NAME}" "${GROUP_ID}" "${QUIET}"

  if [ ! -z "${DEBUG}" ] || [ -z ${QUIET} ]; then
    su --command "printf \"\n$(output_green)Running $(output_bold)${COMMAND}$(output_reset)$(output_green) as \$(id \$(id -nu)) ...\n\n$(output_reset)\"" "${USER_NAME}"
  fi
  if [ "${COMMAND}" = "sh" ]; then
    su "${USER_NAME}"
    local EXIT_CODE=$?
    print_exit_code "${DEBUG}" "${EXIT_CODE}" "${QUIET}"
    exit ${EXIT_CODE}
  else
    su --command "${COMMAND}" "${USER_NAME}"
    local EXIT_CODE=$?
    print_exit_code "${DEBUG}" "${EXIT_CODE}" "${QUIET}"
    exit ${EXIT_CODE}
  fi
}

function run_non_root() {
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

# "How do I parse command line arguments in Bash?"
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash

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
