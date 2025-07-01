#!/bin/sh

# checkout target branch for updates
checkout() {
    write_out -1 "检出同步目标分支 '${INPUT_TARGET_SYNC_BRANCH}'."

    # shellcheck disable=SC2086
    git checkout ${INPUT_TARGET_BRANCH_CHECKOUT_ARGS} "${INPUT_TARGET_SYNC_BRANCH}"
    COMMAND_STATUS=$?

    if [ "${COMMAND_STATUS}" != 0 ]; then
        # exit on branch checkout fail
        write_out "${COMMAND_STATUS}" "同步目标分支 '${INPUT_TARGET_SYNC_BRANCH}' 检出失败."
    fi

    write_out -1 "同步目标分支检出"
    write_out "g" "完成\n"
}
