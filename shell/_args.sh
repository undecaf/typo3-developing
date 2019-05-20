#!/bin/bash

#
# Provides commonly used functions and environment variables.
#
# Usage: source _args.sh $@ (pass the caller's command line arguments)
#


# --------------------------------------------------------------------------

# Prints $USAGE and an optional error message to stdout or stderr
# and exits with error code 0 or 1, respectively.
#
# Arguments:
#   $1  (optional) error message: if specified then it is printed, and all
#       output is sent to stderr; otherwise $USAGE goes to stdout.
# Requires:
#   $USAGE usage information; preserving linefeeds in $USAGE:
#       USAGE=$(cat <<-EOF
#           ... multiline text ...
#       EOF
#       )
#
usage() {
    local SCRIPT=$(basename $0)
    local REDIR=
    local EXIT_CODE=0

    if [ -n "$1" ]; then
        cat >&2 <<- EOF

*** $1 ***
EOF
        REDIR=">&2"
    EXIT_CODE=1
    fi

    eval 'echo "$USAGE" '$REDIR
    exit $EXIT_CODE
}

# --------------------------------------------------------------------------

# Constants
REPO_SLUG=undecaf/typo3-dev
TYPO3_ROOT=/var/www/localhost

# Default options, overridden by environment variables
TAG=${TYPO3DEV_TAG:-latest}
ENGINE=${TYPO3DEV_ENGINE:-$(which podman)} || ENGINE=docker
NAME=${TYPO3DEV_NAME:-typo3}
T3_VOL=${TYPO3DEV_ROOT:-typo3-vol}
DB_TYPE=
DB_VOL=

# Process command line options
while [[ $# -gt 0 ]]; do
    # Check for allowed options if regular expression ALLOWED_OPTS exists
    [ -n "$ALLOWED_OPTS" ] && ! [[ "$1" =~ $ALLOWED_OPTS ]] && break

    case "$1" in
        # Database type
        -d|--database)
            DB_TYPE=
            [ "$2" = m ] && DB_TYPE=mariadb
            [ "$2" = p ] && DB_TYPE=postgresql
            [ -z "$DB_TYPE" ] && usage "Unknown database type: '$2'"
            shift 2
            ;;

        # Container engine
        -e|--engine)
            ENGINE=$2  # basename or absolute path of an executable
            shift 2
            ;;

        # Container name
        -n|--name)
            NAME="$2"
            shift 2
            ;;

        # Image tag
        -t|--tag)
            TAG=$2
            shift 2
            ;;

        # TYPO3 or database volume (volume name or absolute path)
        -v|--typo3-vol|-w|--db-vol)
            RE='^/.+'
            [[ "$2" =~ $RE ]] && [ ! -d "$2" ] && usage "Volume directory '$2' not found"

            case $1 in
                -v|--typo3-vol)
                    T3_VOL=$2
                    ;;
                -w|--db-vol)
                    DB_VOL=$2
                    ;;
            esac
            shift 2
            ;;

        # Help
        -h|--help)
            usage
            shift
            ;;

        # Separator between t3run and Docker options
        --)
            shift
            break
            ;;

        # First option to be passed through to the container engine
        *)
            break
            ;;
    esac
done

# Determine container engine name
[ -x "$(which $ENGINE)" ] || usage "Container engine '$ENGINE' not found"

ENGINE=$(which $ENGINE)
ENGINE_NAME=$(basename $ENGINE)

# Validate database type if database volume was specified
[ -n "$DB_VOL" ] && [ -z "$DB_TYPE" ] && usage "Database type is missing"

# Eventually set a default value for the database volume
if [ -n "$DB_TYPE" -a -z "$DB_VOL" ]; then
    DB_VOL=${TYPO3DEV_DB:-${DB_TYPE}-vol}
fi

# Options that differ between container engines
case $ENGINE_NAME in
    docker)
        HOST_IP_ENV=
        HOST_IP_OPT=
        MP_FORMAT='{{.Mountpoint}}'
        SUDO_PREFIX=sudo
        ;;

    podman)
        HOST_IP_ENV="HOST_IP=$(hostname -I | awk '{print $1}')"
        HOST_IP_OPT="--env $HOST_IP_ENV"
        MP_FORMAT='{{.MountPoint}}'
        SUDO_PREFIX=
        ;;
esac