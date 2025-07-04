#!/bin/sh

# push to origin target_sync_branch
push_new_commits() {
    write_out -1 '将同步更改推向目标分支.'

    # TODO: figure out how this would work in local mode...
    # update remote url with token since it is not persisted during checkout step when syncing from a private repo
    if [ -n "${INPUT_TARGET_REPO_TOKEN}" ]; then
        git remote set-url origin "https://${GITHUB_ACTOR}:${INPUT_TARGET_REPO_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
    fi

    # shellcheck disable=SC2086
    git push ${INPUT_TARGET_BRANCH_PUSH_ARGS} origin "${INPUT_TARGET_SYNC_BRANCH}"
    COMMAND_STATUS=$?

    if [ "${COMMAND_STATUS}" != 0 ]; then
        # exit on push to target repo fail
        write_out "${COMMAND_STATUS}" "无法将更改推向目标分支."
    fi
    
    write_out "g" '完成\n'
}
