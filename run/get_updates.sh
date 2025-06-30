#!/bin/sh

# shellcheck disable=SC2086

# check latest commit hashes for a match, exit if nothing to sync
check_for_updates() {
    write_out -1 'Checking for new commits on upstream branch.\n'

    # fetch commits from upstream branch within given time frame (default 1 month)
    git fetch --quiet --shallow-since="${INPUT_SHALLOW_SINCE}" upstream "${INPUT_UPSTREAM_SYNC_BRANCH}"
    COMMAND_STATUS=$?
    
    echo "测试1"
    if [ "${COMMAND_STATUS}" != 0 ]; then
        # if shallow fetch fails, no new commits are avilable for sync
        HAS_NEW_COMMITS=false
        HAS_NEW_TAGS=false
        set_out_put
        exit_no_commits
    fi
    echo "测试2"

    UPSTREAM_COMMIT_HASH=$(git rev-parse "upstream/${INPUT_UPSTREAM_SYNC_BRANCH}")
    UPSTREAM_COMMIT_TAG=$(git describe "upstream/${INPUT_UPSTREAM_SYNC_BRANCH}" --tags --abbrev=0 2>/dev/null)

    # check is latest upstream hash is in target branch
    git fetch --quiet --shallow-since="${INPUT_SHALLOW_SINCE}" origin "${INPUT_TARGET_SYNC_BRANCH}"
    BRANCH_WITH_LATEST="$(git branch "${INPUT_TARGET_SYNC_BRANCH}" --contains="${UPSTREAM_COMMIT_HASH}")"
    BRANCH_TAG_LATEST=$(git describe "${INPUT_TARGET_SYNC_BRANCH}" --tags --abbrev=0 2>/dev/null)

    if [ -z "${UPSTREAM_COMMIT_HASH}" ]; then
        HAS_NEW_COMMITS="error"
    elif [ -n "${BRANCH_WITH_LATEST}" ]; then
        HAS_NEW_COMMITS=false
    else
        HAS_NEW_COMMITS=true
    fi
    
    echo "${UPSTREAM_COMMIT_TAG}"
    echo "${BRANCH_TAG_LATEST}"
    echo "测试3"
    if [ -z "${UPSTREAM_COMMIT_TAG}" ]; then
    	if [ -z "${BRANCH_TAG_LATEST}" ]; then
    		HAS_NEW_TAGS=false
    	else
    		HAS_NEW_TAGS="error"
    	fi
    elif [ "${UPSTREAM_COMMIT_TAG}" = "${BRANCH_TAG_LATEST}" ]; then
    	HAS_NEW_TAGS=false
    else
    	HAS_NEW_TAGS=true
    fi

    # output 'has_new_commits' value to workflow environment
    set_out_put
    echo "测试4"
    # early exit if no new commits or something failed
    if [ "${HAS_NEW_COMMITS}" = false ] && [ "${HAS_NEW_TAGS}" = false ]; then
        exit_no_commits
    elif [ "${HAS_NEW_COMMITS}" = "error" ] && [ "${HAS_NEW_TAGS}" = "error" ]; then
        write_out 95 'There was an error checking for new commits.'
    fi
}

exit_no_commits() {
    write_out 0 'No new commits to sync. Finishing sync action gracefully.'
}

set_out_put() {
    echo "has_new_commits=${HAS_NEW_COMMITS}" >> $GITHUB_OUTPUT
    echo "has_new_tags=${HAS_NEW_TAGS}" >> $GITHUB_OUTPUT
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
        write_out -1 "\nNo previous sync found from upstream repo. Syncing entire commit history."
        UNSHALLOW=true
    else
        write_out -1 '\nNew commits since last sync:'
        git log upstream/"${INPUT_UPSTREAM_SYNC_BRANCH}" "${LAST_SYNCED_COMMIT}"..HEAD ${INPUT_GIT_LOG_FORMAT_ARGS}
    fi

    if [ "${HAS_NEW_TAGS}" = true ]; then
    	write_out -1 '\nNew tags since last sync:'
    	UPSTREAM_TAGS="$(git ls-remote --tags --quiet --sort=-v:refname upstream)"
    	for tag in ${UPSTREAM_TAGS}; do
    		UP_TAG="$(awk -F'refs/tags/' '{if (NF>1) print $2}' "${tag}" | sed 's/\^\{\}$//')"
    		if [ "${UP_TAG}" != "${BRANCH_TAG_LATEST}" ]; then
    			echo -e "new tag: ${UP_TAG}\n"
    		else
    			break
    		fi
    	done
    else
    	write_out -1 '\nNo found tags.'
    fi
}

# sync from upstream to target_sync_branch
sync_new_commits() {
    write_out -1 '\nSyncing new commits...'

    if [ "${UNSHALLOW}" = true ]; then
        git repack -d upstream "${INPUT_UPSTREAM_SYNC_BRANCH}"
        git pull --unshallow --no-edit ${INPUT_UPSTREAM_PULL_ARGS} upstream "${INPUT_UPSTREAM_SYNC_BRANCH}"
    else
        # pull_args examples: "--ff-only", "--tags", "--ff-only --tags"
        git pull --no-edit ${INPUT_UPSTREAM_PULL_ARGS} upstream "${INPUT_UPSTREAM_SYNC_BRANCH}"
    fi

    COMMAND_STATUS=$?

    if [ "${COMMAND_STATUS}" != 0 ]; then
        # exit on commit pull fail
        write_out "${COMMAND_STATUS}" "New commits could not be pulled."
    fi

    write_out "g" 'SUCCESS\n'
}
