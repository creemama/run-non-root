# run-non-root
Run Linux commands as a non-root user, creating a non-root user if necessary.

```
Usage:
  run-non-root [options] [--] [COMMAND] [ARGS...]

Options:
  -d, --debug              Output debug information;
                           using --quiet does not silence debug output.
  -f, --gname GROUP_NAME   The group name to use when executing the command;
                           the default is non-root-group;
                           when specified, this option overrides the
                           RUN_NON_ROOT_GROUP_NAME environment variable.
  -g, --gid GROUP_ID       The group ID to use when executing the command;
                           the default is the first unused group ID
                           strictly less than 1000;
                           when specified, this option overrides the
                           RUN_NON_ROOT_GROUP_ID environment variable.
  -h, --help               Output this help message and exit.
  -q, --quiet              Do not output "Running COMMAND as USER_INFO ..."
                           or warnings; this option does not silence debug output.
  -t, --uname USER_NAME    The user name to use when executing the command;
                           the default is non-root-user;
                           when specified, this option overrides the
                           RUN_NON_ROOT_USER_NAME environment variable.
  -u, --uid USER_ID        The user ID to use when executing the command;
                           the default is the first unused user ID
                           strictly less than 1000;
                           when specified, this option overrides the
                           RUN_NON_ROOT_USER_ID environment variable.

Environment Variables:
  RUN_NON_ROOT_COMMAND     The command to execute if a command is not given;
                           the default is sh.
  RUN_NON_ROOT_GROUP_ID    The group ID to use when executing the command;
                           the default is the first unused group ID
                           strictly less than 1000;
                           the -g or --gid options override this environment variable.
  RUN_NON_ROOT_GROUP_NAME  The user name to use when executing the command;
                           the default is non-root-group;
                           the -f or --gname options override this environment variable.
  RUN_NON_ROOT_USER_ID     The user ID to use when executing the command;
                           the default is the first unused user ID
                           strictly less than 1000;
                           the -u or --uid options override this environment variable.
  RUN_NON_ROOT_USER_NAME   The user name to use when executing the command;
                           the default is non-root-user;
                           the -t or --uname options override this environment variable.
```
