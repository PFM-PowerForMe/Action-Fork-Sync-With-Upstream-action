#!/bin/sh

# shellcheck disable=SC2086

# check latest commit hashes for a match, exit if nothing to sync
check_for_updates() {
    write_out -1 '从上游检出最新提交.\n'

    # fetch commits from upstream branch within given time frame (default 1 month)
    git fetch --quiet --tags --shallow-since="${INPUT_SHALLOW_SINCE}" upstream "${INPUT_UPSTREAM_SYNC_BRANCH}"
    COMMAND_STATUS=$?
    
    if [ "${COMMAND_STATUS}" != 0 ]; then
        # if shallow fetch fails, no new commits are avilable for sync
        HAS_NEW_COMMITS=false
        HAS_NEW_TAGS=false
        VERSION="error"
        set_out_put
        exit_no_commits
    fi

    UPSTREAM_COMMIT_HASH=$(git rev-parse "upstream/${INPUT_UPSTREAM_SYNC_BRANCH}")
    UPSTREAM_COMMIT_TAG=$(git describe --tags --abbrev=0 "upstream/${INPUT_UPSTREAM_SYNC_BRANCH}" 2>/dev/null)
    for TAG in $(git tag); do
  		git tag -d "${TAG}" > /dev/null 2>&1
	done

    # check is latest upstream hash is in target branch
    git fetch --quiet --tags --shallow-since="${INPUT_SHALLOW_SINCE}" origin "${INPUT_TARGET_SYNC_BRANCH}"
    BRANCH_WITH_LATEST="$(git branch "${INPUT_TARGET_SYNC_BRANCH}" --contains="${UPSTREAM_COMMIT_HASH}")"
    BRANCH_TAG_LATEST=$(git describe "${INPUT_TARGET_SYNC_BRANCH}" --tags --abbrev=0 2>/dev/null)
    git fetch upstream --quiet --tags

    if [ -z "${UPSTREAM_COMMIT_HASH}" ]; then
        HAS_NEW_COMMITS="error"
    elif [ -n "${BRANCH_WITH_LATEST}" ]; then
        HAS_NEW_COMMITS=false
    else
        HAS_NEW_COMMITS=true
    fi

    if [ -z "${UPSTREAM_COMMIT_TAG}" ]; then
    	if [ -z "${BRANCH_TAG_LATEST}" ]; then
    		HAS_NEW_TAGS=false
    		VERSION="error"
    	else
    		HAS_NEW_TAGS="error"
    		VERSION="error"
    	fi
    elif [ "${UPSTREAM_COMMIT_TAG}" = "${BRANCH_TAG_LATEST}" ]; then
    	HAS_NEW_TAGS=false
    	VERSION="error"
    else
    	HAS_NEW_TAGS=true
    	VERSION=${UPSTREAM_COMMIT_TAG}
    fi
	
    # output 'has_new_commits' value to workflow environment
    set_out_put

    # early exit if no new commits or something failed
    if [ "${HAS_NEW_COMMITS}" = false ] && [ "${HAS_NEW_TAGS}" = false ]; then
        exit_no_commits
    elif [ "${HAS_NEW_COMMITS}" = "error" ] && [ "${HAS_NEW_TAGS}" = "error" ]; then
        write_out 95 '检出最新提交错误.'
    fi
}

exit_no_commits() {
    write_out 0 '没有需要同步的新提交. Action 完成.'
}

set_out_put() {
	
    echo "has_new_commits=${HAS_NEW_COMMITS}" >> $GITHUB_OUTPUT
    
    echo "has_new_tags=${HAS_NEW_TAGS}" >> $GITHUB_OUTPUT
    echo "version=${VERSION}" >> $GITHUB_OUTPUT
}

find_last_synced_commit() {
    LAST_SYNCED_COMMIT=""
    TARGET_BRANCH_LOG="$(git rev-list "${INPUT_TARGET_SYNC_BRANCH}")"
    UPSTREAM_BRANCH_LOG="$(git rev-list "upstream/${INPUT_UPSTREAM_SYNC_BRANCH}")"

    for hash in ${TARGET_BRANCH_LOG}; do
        UPSTREAM_CHECK="$(echo "${UPSTREAM_BRANCH_LOG}" | grep "${hash}")"
        if [ -n "${UPSTREAM_CHECK}" ]; then
            LAST_SYNCED_COMMIT="${hash}"
            break
        fi
    done
}

# display new commits since last sync
output_new_commit_list() {
    if [ "${HAS_NEW_COMMITS}" != true ] || [ -z "${LAST_SYNCED_COMMIT}" ]; then
        write_out -1 "\n没有从上游仓库找到需要同步的提交."
    else
        write_out -1 '\n自上次同步以来的新提交:'
        NEW_COMMIT_LT="$(git log upstream/"${INPUT_UPSTREAM_SYNC_BRANCH}" "${LAST_SYNCED_COMMIT}"..HEAD ${INPUT_GIT_LOG_FORMAT_ARGS})"
        for NML in ${NEW_COMMIT_LT}; do
        	write_out -1 "新提交: ${NML}\n"
        done
    fi

    if [ "${HAS_NEW_TAGS}" = true ]; then
    	write_out -1 '\n自上次同步以来的新标签:'
    	UPSTREAM_TAGS="$(git for-each-ref --sort=-creatordate --format '%(refname:short)' refs/tags)"
    	for UP_TAG in ${UPSTREAM_TAGS}; do
    		if [ "${UP_TAG}" != "${BRANCH_TAG_LATEST}" ]; then
    			write_out -1 "新标签: ${UP_TAG}\n"
    		else
    			break
    		fi
    	done
    else
    	write_out -1 '\n没有从上游仓库找到需要同步的标签.'
    fi
}

# sync from upstream to target_sync_branch
sync_new_commits() {
    write_out -1 '\n同步...'

    # if [ "${UNSHALLOW}" = true ]; then
        # git repack -d upstream "${INPUT_UPSTREAM_SYNC_BRANCH}"
        # git pull --unshallow --no-edit ${INPUT_UPSTREAM_PULL_ARGS} upstream "${INPUT_UPSTREAM_SYNC_BRANCH}"
    # else
        # # pull_args examples: "--ff-only", "--tags", "--ff-only --tags"
        # git pull --no-edit ${INPUT_UPSTREAM_PULL_ARGS} upstream "${INPUT_UPSTREAM_SYNC_BRANCH}"
    # fi
    
    git pull --no-edit ${INPUT_UPSTREAM_PULL_ARGS} upstream "${INPUT_UPSTREAM_SYNC_BRANCH}"

    COMMAND_STATUS=$?

    if [ "${COMMAND_STATUS}" != 0 ]; then
        # exit on commit pull fail
        write_out "${COMMAND_STATUS}" "新的提交无法拉取."
    fi

    write_out "g" '完成\n'
}
