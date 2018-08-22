# run-non-root

> Run Linux commands as a non-root user, creating a non-root user if necessary.

<p>
  <a href="https://travis-ci.org/creemama/run-non-root"><img alt="Travis CI Build Status" src="https://img.shields.io/travis/creemama/run-non-root/master.svg?style=flat-square&label=Travis+CI"></a>
</p>

This allows us to

[**run Docker containers with a non-root user by default**](https://github.com/creemama/docker-run-non-root)

without having to specify a `USER` with hardcoded UIDs and GIDs in our Dockerfiles.

```
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
                          option overrides the RUN_NON_ROOT_GROUP_NAME
                          environment variable.
  -g, --gid GID           The group ID to use when executing the command; the
                          default GID is UID or a new ID determined by
                          groupadd; this option is ignored if we are already
                          running as a non-root user; this option overrides the
                          RUN_NON_ROOT_GID environment variable.
  -h, --help              Output this help message and exit.
  -q, --quiet             Do not output "Running ( COMMAND ) as USER_INFO ..."
                          or warnings; this option does not silence --debug
                          output.
  -t, --user USERNAME     The username to use when executing the command; the
                          default is nonroot; this option is ignored if we are
                          already running as a non-root user or if the UID
                          already exists; this option overrides the
                          RUN_NON_ROOT_USERNAME environment variable.
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
  export RUN_NON_ROOT_GROUP_NAME=ec2-user
  export RUN_NON_ROOT_UID=1000
  export RUN_NON_ROOT_USERNAME=ec2-user
  run-non-root -- id
```

## Installation

Use the following commands to install or upgrade `run-non-root`:

```sh
wget -O /usr/local/bin/run-non-root https://raw.githubusercontent.com/creemama/run-non-root/master/run-non-root.sh
# curl -L https://raw.githubusercontent.com/creemama/run-non-root/master/run-non-root.sh -o /usr/local/bin/run-non-root
chmod +x /usr/local/bin/run-non-root
```

## Docker and `run-non-root`

For more information about using `run-non-root` with Docker, see [docker-run-non-root](https://github.com/creemama/docker-run-non-root).
