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

RUN_NON_ROOT_VERSION=1.5.1

print_help () {
  cat << EOF

Usage:
  run-non-root [options] [--] [COMMAND] [ARGS...]

Run Linux commands as a non-root user, creating a non-root user if necessary.

Options:
  -c, --chown             Colon-separated list of files and directories to run
                          "chown USERNAME:GID" on before executing the
                          command; you can use this option multiple times
                          instead of using a colon-separated list; run-non-root
                          ignores this option if you are already running as a
                          non-root user; unlike -p this option is non-recursive.
  -d, --debug             Output debug information; using --quiet does not
                          silence debug output. Double up (-dd) for more output.
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
  -p, --path              Colon-separated list of directories to run
                          "chown -R USERNAME:GID" on before executing the
                          command; you can use this option multiple times
                          instead of using a colon-separated list; if a
                          directory does not exist, run-non-root attempts to
                          create it; run-non-root ignores this option if you
                          are already running as a non-root user; unlike -c
                          this option is recursive.
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
                          default is bash; if bash does not exist, the default
                          is sh.
  RUN_NON_ROOT_GID        The group ID to use when executing the command; see
                          the --gid option for more info.
  RUN_NON_ROOT_GROUP      The group name to use when executing the command; see
                          the --group option for more info.
  RUN_NON_ROOT_UID        The user ID to use when executing the command; see
                          the --uid option for more info.
  RUN_NON_ROOT_USER       The username to use when executing the command; see
                          the --user option for more info.

Examples:
  # Run bash or sh as a non-root user.
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

add_group () {
  local debug="$1"
  local local_gid="$2"
  local local_group_name="$3"
  local quiet="$4"
  local return_gid="$5"
  local return_group_name="$6"
  local uid="$7"
  local username="$8"

  if [ -z "${local_group_name}" ]; then
    if test_group_exists "${username}"; then
      if [ "${username}" = 'nonroot' ]; then
        # The nonroot group already exists.
        eval $return_gid="'$(
          getent group nonroot | awk -F ':' '{print $3}'
        )'"
        eval $return_group_name="'nonroot'"
        return
      fi
      local_group_name='nonroot'
    else
      local_group_name="${username}"
    fi
  fi

  if [ -z "${local_gid}" ] \
  && [ -n "${uid}" ] \
  && ! test_group_exists "${uid}"; then
    local_gid="${uid}"
  fi

  check_for_groupadd "${debug}" "${quiet}"

  # "groupadd(8) - Linux man page"
  # https://linux.die.net/man/8/groupadd

  if ! eval_command \
    "$(
      print_s 'groupadd'
      if [ -n "${local_gid}" ]; then
        print_s " --gid \"${local_gid}\""
      fi
      print_s " \"${local_group_name}\""
    )" \
    "${debug}" \
    'y'; then
    local gid_part=''
    if [ -n "${local_gid}" ]; then
      gid_part=" with ID ( ${local_gid} )"
    fi
    exit_with_error 100 \
      "We could not add the group ( ${local_group_name} )${gid_part}."
  fi

  if [ -z "${local_gid}" ]; then
    local_gid="$(getent group ${local_group_name} | awk -F ':' '{print $3}')"
  fi

  eval $return_gid="'${local_gid}'"
  eval $return_group_name="'${local_group_name}'"
}

add_user () {
  local debug="$1"
  local gid="$2"
  local quiet="$3"
  local uid="$4"
  local username="$5"

  if [ -z "${uid}" ] && ! test_user_exists "${gid}"; then
    uid="${gid}"
  fi

  check_for_useradd "${debug}" "${quiet}"

  # "useradd(8) - Linux man page"
  # https://linux.die.net/man/8/useradd

  # In alpine:3.7, useradd set the shell to /bin/bash even though it does not exist.
  # As such, we set "--shell /bin/sh".

  if ! eval_command \
    "$(
      print_s 'useradd'
      print_s ' --create-home'
      print_s " --gid \"${gid}\""
      print_s ' --no-log-init'
      if test_command_exists 'bash'; then
        print_s ' --shell /bin/bash'
      else
        print_s ' --shell /bin/sh'
      fi
      if [ -n "${uid}" ]; then
        print_s " --uid \"${uid}\""
      fi
      print_s " \"${username}\""
    )" \
    "${debug}" \
    'y'; then
    local uid_part=''
    if [ -n "${uid}" ]; then
      uid_part=" with ID ( ${uid} )"
    fi
    exit_with_error 200 "We could not add the user ( ${username} )${uid_part}."
  fi
}

apk_add_shadow () {
  local debug="$1"
  local quiet="$2"
  eval_command 'apk update' "${debug}" "${quiet}"
  eval_command 'apk add shadow' "${debug}" "${quiet}"
}

apk_add_su_exec () {
  local debug="$1"
  local quiet="$2"
  eval_command 'apk update' "${debug}" "${quiet}"
  eval_command 'apk add su-exec' "${debug}" "${quiet}"
}

apk_add_tini () {
  local debug="$1"
  local quiet="$2"
  eval_command \
    "$(
      print_s 'wget'
      print_s ' -O /usr/local/bin/tini'
      print_s ' https://github.com/krallin/tini/releases/download/v0.18.0/tini-static'
    )" \
    "${debug}" \
    "${quiet}"
  eval_command 'chmod +x /usr/local/bin/tini' "${debug}" 'y'
}

apt_get_install_su_exec () {
  local debug="$1"
  local quiet="$2"
  eval_command 'apt-get update' "${debug}" "${quiet}"
  eval_command 'apt-get install -y curl gcc make unzip' "${debug}" "${quiet}"
  curl_su_exec "${debug}" "${quiet}"
}

apt_get_install_tini () {
  local debug="$1"
  local quiet="$2"
  eval_command 'apt-get update' "${debug}" "${quiet}"
  eval_command 'apt-get install -y curl' "${debug}" "${quiet}"
  curl_tini "${debug}" "${quiet}"
}

check_for_getopt () {
  local debug="$1"
  local quiet="$2"
  if ! test_command_exists 'getopt'; then
    if test_command_exists 'yum'; then
      yum_install_getopt "${debug}" "${quiet}"
    fi
  fi
}

check_for_groupadd () {
  local debug="$1"
  local quiet="$2"
  if ! test_command_exists 'groupadd'; then
    if test_command_exists 'apk'; then
      apk_add_shadow "${debug}" "${quiet}"
    fi
  fi
}

check_for_su_exec () {
  local debug="$1"
  local quiet="$2"
  if ! test_command_exists 'su-exec'; then

    # "Package Management Basics: apt, yum, dnf, pkg"
    # https://www.digitalocean.com/community/tutorials/package-management-basics-apt-yum-dnf-pkg.

    if test_command_exists 'apk'; then
      apk_add_su_exec "${debug}" "${quiet}"
      return "$?"
    fi
    if test_command_exists 'apt-get'; then
      apt_get_install_su_exec "${debug}" "${quiet}"
      return "$?"
    fi
    if test_command_exists 'yum'; then
      yum_install_su_exec "${debug}" "${quiet}"
      return "$?"
    fi
  fi
}

check_for_tini () {
  local debug="$1"
  local quiet="$2"
  if ! test_command_exists 'tini'; then
    if test_command_exists 'apk'; then
      apk_add_tini "${debug}" "${quiet}"
      return "$?"
    fi
    if test_command_exists 'apt-get'; then
      apt_get_install_tini "${debug}" "${quiet}"
      return "$?"
    fi
    if test_command_exists 'yum'; then
      yum_install_tini "${debug}" "${quiet}"
      return "$?"
    fi
  fi
}

check_for_useradd () {
  local debug="$1"
  local quiet="$2"
  if ! test_command_exists 'useradd'; then
    if test_command_exists 'apk'; then
      apk_add_shadow "${debug}" "${quiet}"
    fi
  fi
  if test_command_exists 'apk'; then
    # In alpine:3.7, unless we execute the following command, we get the
    # following error after calling useradd:
    # Creating mailbox file: No such file or directory
    eval_command 'mkdir -p /var/mail' "${debug}" 'y'
  fi
}

curl_su_exec () {
  # The -L (or --location) option follows redirects.
  eval_command \
    "$(
      print_s 'curl'
      print_s ' -L'
      print_s ' https://github.com/ncopa/su-exec/archive/dddd1567b7c76365e1e0aac561287975020a8fad.zip'
      print_s ' -o su-exec.zip'
    )" \
    "${debug}" \
    "${quiet}"
  eval_command 'unzip su-exec.zip' "${debug}" "${quiet}"
  eval_command 'cd su-exec-dddd1567b7c76365e1e0aac561287975020a8fad' "${debug}" 'y'
  eval_command 'make' "${debug}" "${quiet}"
  eval_command 'mv su-exec /usr/local/bin' "${debug}" 'y'
  eval_command 'cd ..' "${debug}" 'y'
  eval_command 'rm -rf su-exec-dddd1567b7c76365e1e0aac561287975020a8fad' "${debug}" 'y'
}

curl_tini () {
  # The -L (or --location) option follows redirects.
  eval_command \
    "$(
      print_s 'curl'
      print_s ' -L'
      print_s ' https://github.com/krallin/tini/releases/download/v0.18.0/tini-static'
      print_s ' -o /usr/local/bin/tini'
    )" \
    "${debug}" \
    "${quiet}"
  eval_command 'chmod +x /usr/local/bin/tini' "${debug}" 'y'
}

escape_double_quotation_marks () {
  print_s "$1" | sed 's/"/\\"/g'
}

eval_command () {
  local command="$1"
  local debug="$2"
  local quiet="$3"

  if [ "${quiet}" = 'y' ]; then
    command="${command} > /dev/null 2>&1"
  fi

  ([ "${debug}" = 'y' ] || [ ! "${quiet}" = 'y' ]) \
  && print_ns "$(output_cyan)Executing$(output_reset) ${command} ... "

  [ ! "${quiet}" = 'y' ] && print_sn ''

  eval "${command}" || return "$?"

  ([ "${debug}" = 'y' ] || [ ! "${quiet}" = 'y' ]) \
  && print_sn "$(output_cyan)DONE$(output_reset)"

  return 0
}

exit_with_error () {
  local exit_code="$1"
  local message="$2"
  (>&2
    print_s "$(output_red)$(output_bold)ERROR (${exit_code}):$(output_reset)"
    print_sn "$(output_red) ${message}$(output_reset)"
  )
  exit "${exit_code}"
}

local_tput () {
  if ! test_is_tty; then
    return 0
  fi
  if test_command_exists 'tput'; then
    # $@ is unquoted.
    tput $@
  fi
}

main () {
  local chowner=''
  local command="${RUN_NON_ROOT_COMMAND:-}"
  local debug=''
  local gid="${RUN_NON_ROOT_GID:-}"
  local group_name="${RUN_NON_ROOT_GROUP:-}"
  local init=''
  local path=''
  local quiet=''
  local uid="${RUN_NON_ROOT_UID:-}"
  local username="${RUN_NON_ROOT_USER:-}"

  # "How do I parse command line arguments in Bash?"
  # https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash

  # "How to store standard error in a variable"
  # https://stackoverflow.com/questions/962255/how-to-store-standard-error-in-a-variable

  # debug and quiet are not available yet.
  check_for_getopt 'y' 'y'

  local parsed_options
  if ! parsed_options="$(
    getopt \
      --options=c:df:g:hip:qt:u:v \
      --longoptions=chown:,debug,gid:,group:,help,init,path:,quiet,uid:,user:,version \
      --name "$0" \
      -- "$@" 2>&1
  )"; then
    exit_with_error 1 \
      "$(
        print_s 'There was an error parsing the given options. '
        print_s 'You may need to (a) remove invalid options or '
        print_s "(b) use -- to separate run-non-root's options "
        print_s 'from the command. '
        print_s 'Run run-non-root --help for more info. '
        print_s "(From getopt: ${parsed_options})"
      )"
  fi

  eval set -- "${parsed_options}"
  while true; do
    case "$1" in
      -c|--chown)
        if [ -z "${chowner}" ]; then
          chowner="$2"
        else
          chowner="${chowner}:$2"
        fi
        shift 2
        ;;
      -d|--debug)
        if [ "${debug}" = 'y' ]; then
          # "Showing the running command in a bash script with "set -x""
          # https://www.stefaanlippens.net/set-x/
          set -o xtrace
        fi
        debug='y'
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
        init='y'
        shift
        ;;
      -p|--path)
        if [ -z "${path}" ]; then
          path="$2"
        else
          path="${path}:$2"
        fi
        shift 2
        ;;
      -q|--quiet)
        quiet='y'
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

  # The following if statement ensures that we preserve quotation marks in
  # commands.

  # For example, if the user enters
  #   run-non-root -- echo "foo bar"
  # we want the command to be
  #   echo "foo bar"
  # and not
  #   echo foo bar

  if [ -n "${1:-}" ]; then
    command="$(stringify_arguments "$@")"
  fi

  if [ "${debug}" = 'y' ]; then
    cat << EOF

$(output_cyan)Command Options:$(output_reset)
  $(output_cyan)chown=$(output_reset)${chowner}
  $(output_cyan)command=$(output_reset)${command}
  $(output_cyan)debug=$(output_reset)${debug}
  $(output_cyan)gid=$(output_reset)${gid}
  $(output_cyan)group_name=$(output_reset)${group_name}
  $(output_cyan)init=$(output_reset)${init}
  $(output_cyan)path=$(output_reset)${path}
  $(output_cyan)quiet=$(output_reset)${quiet}
  $(output_cyan)uid=$(output_reset)${uid}
  $(output_cyan)username=$(output_reset)${username}
EOF
  fi

  # Since we are using eval to execute groupadd and useradd, ensure that users
  # do not try to inject code via group_name or username through the clever
  # usage of quotation marks.

  # For example,
  #   malicious_string="foo\"; echo \"bar"
  #   command=$(echo echo \"${malicious_string}\")
  #   echo "${command}"
  #   eval "${command}"
  # These commands output:
  #   echo "foo"; echo "bar"
  #   foo
  #   bar

  if ! [ -z "${group_name}" ] \
  && test_contains_double_quotation_mark "${group_name}"; then
    exit_with_error 3 \
      "$(
        print_s 'The group name must not contain a double quotation mark; '
        print_s "it is ( ${group_name} )."
      )"
  fi

  if ! [ -z "${username}" ] \
  && test_contains_double_quotation_mark "${username}"; then
    exit_with_error 4 \
      "$(
        print_s 'The username must not contain a double quotation mark; '
        print_s "it is ( ${username} )."
      )"
  fi

  if ! [ -z "${gid}" ] \
  && (! test_is_integer "${gid}" || [ "${gid}" -lt 0 ]); then
    exit_with_error 5 \
      "The GID must be a nonnegative integer; it is ( ${gid} )."
  fi

  if ! [ -z "${uid}" ] \
  && (! test_is_integer "${uid}" || [ "${uid}" -lt 0 ]); then
    exit_with_error 6 \
      "The UID must be a nonnegative integer; it is ( ${uid} )."
  fi

  run_non_root \
    "${chowner}" \
    "${command}" \
    "${debug}" \
    "${gid}" \
    "${group_name}" \
    "${init}" \
    "${path}" \
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
  printf '\n%s' "${1}"
}

print_snn () {
  printf '%s\n\n' "${1}"
}

print_s () {
  printf '%s' "${1}"
}

print_sn () {
  printf '%s\n' "${1}"
}

print_warning () {
  print_ns "$(output_yellow)$(output_bold)WARNING:$(output_reset)"
  print_sn "$(output_yellow) $1$(output_reset)"
}

run_as_current_user () {
  local command="${1:-sh}"
  local debug="$2"
  local init="$3"
  local quiet="$4"

  local tini_part=''
  if [ "${init}" = 'y' ]; then
    check_for_tini "${debug}" "${quiet}"
    tini_part='tini -- '
  fi

  if [ "${debug}" = 'y' ] || [ ! "${quiet}" = 'y' ]; then
    print_warning \
      "$(
        print_s 'You are already running as a non-root user. '
        print_s 'We have ignored all group and user options.'
      )"
    print_ns "$(output_green)Running ( "
    print_s "exec ${tini_part}$(output_bold)${command}$(output_reset)"
    print_snn "$(output_green) ) as $(id) ...$(output_reset)"
  fi
  # If we had not used eval, then commands like
  #   sh -c "ls -al" or sh -c "echo 'foo bar'"
  # would have errored with
  #   /usr/local/bin/run-non-root: line 1: exec sh -c "ls -al": not found
  #   'ls: line 1: syntax error: unterminated quoted string
  # or
  #   'foo: line 1: syntax error: unterminated quoted string
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

  local chowner="$1"

  local command=''
  if test_command_exists 'bash'; then
    command="${2:-bash}"
  else
    command="${2:-sh}"
  fi

  local debug="$3"
  local gid="$4"
  local group_name="$5"
  local init="$6"
  local path="$7"
  local quiet="$8"
  local uid="$9"
  local username="${10}"

  local gid_exists=1
  if test_group_exists "${gid}"; then
    gid_exists=0
  fi

  local group_name_exists=1
  if test_group_exists "${group_name}"; then
    group_name_exists=0
  fi

  local uid_exists=1
  if test_user_exists "${uid}"; then
    uid_exists=0
  fi

  local username_exists=1
  if test_user_exists "${username}"; then
    username_exists=0
  fi

  local create_user=''
  local create_group=''

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

  if [ -n "${create_group}" ]; then
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

  if [ -n "${create_user}" ]; then
    add_user \
      "${debug}" \
      "${gid}" \
      "${quiet}" \
      "${uid}" \
      "${username}"
  fi

  if [ -n "${path}" ]; then
    update_ownership_recursively \
      "${debug}" \
      "${gid}" \
      "${path}" \
      "${quiet}" \
      "${username}"
  fi

  if [ -n "${chowner}" ]; then
    update_ownership_non_recursively \
      "${chowner}" \
      "${debug}" \
      "${gid}" \
      "${quiet}" \
      "${username}"
  fi

  local tini_part=''
  if [ "${init}" = 'y' ]; then
    check_for_tini "${debug}" "${quiet}"
    tini_part='tini -- '
  fi

  check_for_su_exec "${debug}" "${quiet}"
  if [ "${debug}" = 'y' ] || [ -z ${quiet} ]; then
    print_ns "$(output_green)Running ( "
    print_s "exec su-exec ${username}:${gid} "
    print_s "${tini_part}$(output_bold)${command}$(output_reset)"
    print_snn "$(output_green) ) as $(id ${username}) ...$(output_reset)"
  fi
  # If we had not used eval, then commands like
  #   sh -c "ls -al" or sh -c "echo 'foo bar'"
  # would have errored with
  #   /usr/local/bin/run-non-root: line 1: exec sh -c "ls -al": not found
  #   'ls: line 1: syntax error: unterminated quoted string
  # or
  #   'foo: line 1: syntax error: unterminated quoted string
  eval "exec su-exec ${username}:${gid} ${tini_part}${command}"
}

run_non_root () {
  local chowner="$1"
  local command="$2"
  local debug="$3"
  local gid="$4"
  local group_name="$5"
  local init="$6"
  local path="$7"
  local quiet="$8"
  local uid="$9"
  local username="${10}"

  if [ "$(whoami)" = 'root' ]; then
    run_as_non_root_user \
      "${chowner}" \
      "${command}" \
      "${debug}" \
      "${gid}" \
      "${group_name}" \
      "${init}" \
      "${path}" \
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
  local command="$(escape_double_quotation_marks "${1}")"
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

test_command_exists () {
  command -v "$1" > /dev/null 2>&1
}

test_contains_double_quotation_mark () {
  local string="$1"
  print_s "$1" | grep '"' > /dev/null
}

test_group_exists () {
  local gid_or_group_name="$1"
  if [ -z "${gid_or_group_name}" ]; then
    return 1
  else
    getent group "${gid_or_group_name}" > /dev/null 2>&1
  fi
}

test_is_integer () {
  [ "$1" -eq "$1" ] 2> /dev/null
}

test_is_tty () {
  # "No value for $TERM and no -T specified"
  # https://askubuntu.com/questions/591937/no-value-for-term-and-no-t-specified
  tty -s > /dev/null 2>&1
}

test_user_exists () {
  local uid_or_username="$1"
  if [ -z "${uid_or_username}" ]; then
    return 1
  else
    getent passwd "${uid_or_username}" > /dev/null 2>&1
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

  local local_create_group=''

  if [ "${gid_exists}" -eq 0 ]; then

    local group_name_of_gid="$(
      getent group "${local_gid}" | awk -F ':' '{print $1}'
    )"
    if [ ! "${quiet}" = 'y' ] \
    && [ -n "${local_group_name}" ] \
    && [ "${local_group_name}" != "${group_name_of_gid}" ]; then
      print_warning \
        "$(
          print_s 'We have ignored the group name you specified, '
          print_s "( ${local_group_name} ). The GID you specified, "
          print_s "( ${local_gid} ), exists with the group name "
          print_s "( ${group_name_of_gid} )."
        )"
    fi
    local_group_name="${group_name_of_gid}"

  elif [ "${group_name_exists}" -eq 0 ]; then

    if [ -z "${local_gid}" ]; then
      local gid_of_group_name="$(
        getent group "${local_group_name}" | awk -F ':' '{print $3}'
      )"
      local_gid="${gid_of_group_name}"
    else
      local_group_name=''
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

update_ownership_non_recursively() {
  local chowner="$1"
  local debug="$2"
  local gid="$3"
  local quiet="$4"
  local username="$5"

  # "Does `dash` support `bash` style arrays?"
  # https://stackoverflow.com/questions/14594033/does-dash-support-bash-style-arrays
  local old_IFS="$IFS"
  IFS=':'
  set -- ${chowner}
  IFS="${old_IFS}"

  for arg; do

    # Since arg could be anything, we do not call eval_command here.

    local chown_v_option=''
    if [ "${debug}" = 'y' ] && [ ! "${quiet}" = 'y' ]; then
      chown_v_option='-v'
    fi

    ([ "${debug}" = 'y' ] || [ ! "${quiet}" = 'y' ]) \
    && print_ns "$(output_cyan)Executing$(output_reset) " \
    && print_s "chown ${chown_v_option} \"${username}:${gid}\" \"${arg}\"" \
    && print_s ' ... '

    [ ! "${quiet}" = 'y' ] && print_sn ''

    if ! chown ${chown_v_option} "${username}:${gid}" "${arg}" \
    && [ ! "${quiet}" = 'y' ]; then
      print_warning "Something went wrong changing the ownership of ( ${arg} )."
      true
    fi

    ([ "${debug}" = 'y' ] || [ ! "${quiet}" = 'y' ]) \
    && print_sn "$(output_cyan)DONE$(output_reset)"

  done

  return 0
}

update_ownership_recursively() {
  local debug="$1"
  local gid="$2"
  local path="$3"
  local quiet="$4"
  local username="$5"

  # "Does `dash` support `bash` style arrays?"
  # https://stackoverflow.com/questions/14594033/does-dash-support-bash-style-arrays
  local old_IFS="$IFS"
  IFS=':'
  set -- ${path}
  IFS="${old_IFS}"

  for arg; do

    # Since arg could be anything, we do not call eval_command here.

    if [ ! -d "${arg}" ]; then
      ([ "${debug}" = 'y' ] || [ ! "${quiet}" = 'y' ]) \
      && print_ns "$(output_cyan)Executing$(output_reset) " \
      && print_s "mkdir -p \"${arg}\" ... "

      if ! mkdir -p "${arg}"; then
        exit_with_error 300 "We could not create the directory ( ${arg} )."
      fi

      ([ "${debug}" = 'y' ] || [ ! "${quiet}" = 'y' ]) \
      && print_sn "$(output_cyan)DONE$(output_reset)"
    fi

    # If the directory already has the correct UID and GID, then do nothing. We
    # assume here that if the directory already has the correct UID and GID,
    # then the UIDs and GIDs of its contents are also correct. If this
    # assumption is not correct, then handle any requirements outside this
    # script.

    if [ "$(ls -adn "${arg}" | awk -F ' ' '{print $3" "$4}')" = \
         "$(id -u "${username}") ${gid}" ]; then
      if [ ! "${quiet}" = 'y' ]; then
        print_warning "$(
          print_s "We did not call chown on the directory ( ${arg} ). "
          print_s "Its owner is already ( ${username}:${gid} )."
        )"
      fi
      continue
    fi

    local chown_v_option=''
    if [ "${debug}" = 'y' ] && [ ! "${quiet}" = 'y' ]; then
      chown_v_option='-v'
    fi

    ([ "${debug}" = 'y' ] || [ ! "${quiet}" = 'y' ]) \
    && print_ns "$(output_cyan)Executing$(output_reset) " \
    && print_s "chown -R ${chown_v_option} \"${username}:${gid}\" \"${arg}\"" \
    && print_s ' ... '

    [ ! "${quiet}" = 'y' ] && print_sn ''

    if ! chown -R ${chown_v_option} "${username}:${gid}" "${arg}" \
    && [ ! "${quiet}" = 'y' ]; then
      print_warning "Something went wrong changing the ownership of ( ${arg} )."
      true
    fi

    ([ "${debug}" = 'y' ] || [ ! "${quiet}" = 'y' ]) \
    && print_sn "$(output_cyan)DONE$(output_reset)"

  done

  return 0
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

  local local_create_user=''

  if [ "${uid_exists}" -eq 0 ]; then

    # Using id with a UID does not work in Alpine Linux.
    local username_of_uid="$(
      getent passwd "${local_uid}" | awk -F ':' '{print $1}'
    )"
    if [ ! "${quiet}" = 'y' ] \
    && [ -n "${local_username}" ] \
    && [ "${local_username}" != "${username_of_uid}" ]; then
      print_warning \
        "$(
          print_s 'We have ignored the username you specified, '
          print_s "( ${local_username} ). The UID you specified, "
          print_s "( ${local_uid} ), exists with the username "
          print_s "( ${username_of_uid} )."
        )"
    fi
    local_username="${username_of_uid}"

  elif [ "${username_exists}" -eq 0 ]; then

    if [ -z "${local_uid}" ]; then
      local uid_of_username="$(id -u "${local_username}")"
      local_uid="${uid_of_username}"
    else
      local_username='nonroot'
      local_create_user=0
    fi

  else

    if [ -z "${local_username}" ]; then
      local_username='nonroot'
    fi
    local_create_user=0

  fi

  if [ "${local_create_user}" = '0' ] \
  && [ "${local_username}" = 'nonroot' ] \
  && test_user_exists 'nonroot'; then
    local_uid="$(id -u nonroot)"
    local_create_user=''
  fi

  eval $return_uid="'${local_uid}'"
  eval $return_username="'${local_username}'"
  eval $return_create_user="'${local_create_user}'"
}

yum_install_getopt () {
  local debug="$1"
  local quiet="$2"
  eval_command 'yum install -y util-linux-ng' "${debug}" "${quiet}"
}

yum_install_su_exec () {
  local debug="$1"
  local quiet="$2"
  eval_command 'yum install -y gcc make unzip' "${debug}" "${quiet}"
  curl_su_exec
}

yum_install_tini () {
  local debug="$1"
  local quiet="$2"
  curl_tini "${debug}" "${quiet}"
}

main "$@"
