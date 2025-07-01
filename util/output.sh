#!/bin/sh

# output colors
RED="\033[91m"
YELLOW="\033[93m"
GREEN="\033[32m"
BLUE="\033[96m"
BOLD="\033[1m"
NORMAL="\033[m"

# $1 = color OR exit code
# $2 = message
# Set color and output message, exit gracefully if required
write_out() {
    case $1 in
    # default message, normal output
    -1)
        echo "$2" 1>&1
        echo "$2" >> $GITHUB_STEP_SUMMARY
        ;;

    # red output
    [Rr])
        echo "${BOLD}${RED}$2${NORMAL}" 1>&1
        echo "$2" >> $GITHUB_STEP_SUMMARY
        ;;

    # yellow output
    [Yy])
        echo "${BOLD}${YELLOW}$2${NORMAL}" 1>&1
        echo "$2" >> $GITHUB_STEP_SUMMARY
        ;;

    # green output
    [Gg])
        echo "${BOLD}${GREEN}$2${NORMAL}" 1>&1
        echo "$2" >> $GITHUB_STEP_SUMMARY
        ;;

    # green output
    [Bb])
        echo "${BOLD}${BLUE}$2${NORMAL}" 1>&1
        echo "$2" >> $GITHUB_STEP_SUMMARY
        ;;

    # safe exit, green output
    0)
        printf '\n%s\n' "$2" 1>&1
        echo "${BOLD}${GREEN}安全退出${NORMAL}" 1>&1
        echo "安全退出" >> $GITHUB_STEP_SUMMARY
        early_exit_cleanup
        exit 0
        ;;

    # exit on error, red output
    *)
        echo "${BOLD}${RED}错误: ${NORMAL} 退出 $1" 1>&2
        echo "错误: 退出 $1" >> $GITHUB_STEP_SUMMARY
        printf '%s\n' "$2" 1>&2
        printf '%s\n' "Try running in test mode to verify your action input. If that does not help, please open an issue." 1>&2

        early_exit_cleanup
        exit "$1"
        ;;
    esac
}

early_exit_cleanup() {
    reset_git_config
}
