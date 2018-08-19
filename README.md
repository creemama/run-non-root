# run-non-root

Run Linux commands as a non-root user, creating a non-root user if necessary.

This allows us to

[**run Docker containers with a non-root user by default**](https://github.com/creemama/docker-run-non-root)

without having to specify a `USER` in our Dockerfiles.

```
Usage:
  run-non-root [options] [--] [COMMAND] [ARGS...]

Options:
  -d, --debug              Output debug information; using --quiet does not
                           silence debug output.
  -f, --gname GROUP_NAME   The group name to use when executing the command;
                           the default is nonrootgroup; this option is ignored
                           if we are already running as a non-root user; when
                           specified, this option overrides the
                           RUN_NON_ROOT_GROUP_NAME environment variable.
  -g, --gid GROUP_ID       The group ID to use when executing the command;
                           the default is the first unused group ID strictly
                           less than 1000; this option is ignored if we are
                           already running as a non-root user; when specified,
                           this option overrides the RUN_NON_ROOT_GROUP_ID
                           environment variable.
  -h, --help               Output this help message and exit.
  -q, --quiet              Do not output "Running ( COMMAND ) as USER_INFO ..."
                           or warnings; this option does not silence --debug
                           output.
  -t, --uname USER_NAME    The user name to use when executing the command;
                           the default is nonrootuser; this option is ignored
                           if we are already running as a non-root user; when
                           specified, this option overrides the
                           RUN_NON_ROOT_USER_NAME environment variable.
  -u, --uid USER_ID        The user ID to use when executing the command;
                           the default is the first unused user ID strictly
                           less than 1000; this option is ignored if we are
                           already running as a non-root user; when specified,
                           this option overrides the RUN_NON_ROOT_USER_ID
                           environment variable.

Environment Variables:
  RUN_NON_ROOT_COMMAND     The command to execute if a command is not given;
                           the default is sh.
  RUN_NON_ROOT_GROUP_ID    The group ID to use when executing the command; the
                           default is the first unused group ID strictly less
                           than 1000; this variable is ignored if we are
                           already running as a non-root user; the -g and --gid
                           options override this environment variable.
  RUN_NON_ROOT_GROUP_NAME  The group name to use when executing the command;
                           the default is nonrootgroup; this variable is
                           ignored if we are already running as a non-root
                           user; the -f and --gname options override this
                           environment variable.
  RUN_NON_ROOT_USER_ID     The user ID to use when executing the command; the
                           default is the first unused user ID strictly less
                           than 1000; this variable is ignored if we are
                           already running as a non-root user; the -u and --uid
                           options override this environment variable.
  RUN_NON_ROOT_USER_NAME   The user name to use when executing the command; the
                           default is nonrootuser; this option is ignored if we
                           are already running as a non-root user; the -t and
                           --uname options override this environment variable.

Examples:
  # Run sh as a non-root user.
  run-non-root

  # Run id as a non-root user.
  run-non-root -- id

  # Run id as a non-root user using options and the given user specification.
  run-non-root -f ec2-user -g 1000 -t ec2-user -u 1000 -- id

  # Run id as a non-root user using environment variables
  # and the given user specification.
  export RUN_NON_ROOT_GROUP_ID=1000
  export RUN_NON_ROOT_GROUP_NAME=ec2-user
  export RUN_NON_ROOT_USER_ID=1000
  export RUN_NON_ROOT_USER_NAME=ec2-user
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
