#!/bin/bash
set -euo pipefail

HELP="This script syncs multiple git repositories from GitHub.

Ensure you have 'git', 'gh' (GitHub CLI), 'jq' and the necessary permissions to access the repositories you want to back
 up.
If first time running git pull, you may need to set up your SSH keys or authenticate with GitHub, follow the
 instructions at: https://docs.github.com/en/authentication/connecting-to-github-with-ssh

Usage: ./sync-from-github.sh [OPTIONS]
Example: ./sync-from-github.sh --backup-destination-dir ~/github-backup --github-user Teidesat --branch all

Options:
    -d, --backup-destination-dir <backup_destination_dir>
        Destination directory where the repositories will be synced.
        Default value is '\$HOME/github-backup'.

        - If the directory exists, it will be used as the base directory for syncing.
        - Else, it will be created.

    -g, --github-user <github_user>
        GitHub username or organization whose repositories will be synced.
        Default value is 'Teidesat'.

        - If the user or organization exists, the script will sync all repositories.
        - Else, the script will exit with an error.

    -i, --include_repositories <include_pattern>
        Include pattern for repositories to sync. (Whitelisting)
        Default value is empty.

        - If the pattern matches a repository name, only those repositories will be synced.
        - Else if the pattern is empty, all repositories owned by the provided user or organization will be synced.
        - Else, the script will exit with an error.

        Note: The exclude pattern takes prevalence over the include pattern.

    -e, --exclude_repositories <exclude_pattern>
        Exclude pattern for repositories to skip during the sync. (Blacklisting)
        Default value is empty.

        - If the pattern matches a repository name, it will be skipped during the sync.
        - Else if the pattern is empty, all repositories owned by the provided user or organization will be synced.
        - Else, the script will exit with an error.

        Note: The exclude pattern takes prevalence over the include pattern.

    -b, --all_branches
        Include all branches of the repositories in the sync.
        Default value is false, meaning only the default branch of each repository will be synced.

        - If this option is set, all branches of the repositories will be synced.
        - Else, only the default branch of each repository will be synced.

    -m, --pull-mode <pull_mode>
        Mode for pulling changes from the repositories.
        Default value is 'ff-only', which means it will only fast-forward changes.

        - If the mode is 'ff-only', it will only pull changes if the local branch is behind the remote branch.
        - Else if the mode is 'rebase', it will rebase the local changes on top of the remote changes.
        - Else if the mode is 'merge', it will try to merge the local changes with the remote changes, although if there
            are any conflicts, it will exit with an error and ask the user to resolve them manually.
        - Else if the mode is none of the above, the script will exit with an error.

    -r, --recurse-submodules
        If set, the script will also sync submodules of the repositories.
        Default value is false, meaning submodules will not be synced.

        - If this option is set, the script will recursively sync all submodules of the repositories.
        - Else, submodules will not be synced.

    -q, --quiet
        Run the script in quiet mode, suppressing output messages.
        Default value is false, meaning all messages will be printed.

        - If this option is set, only error messages will be printed.
        - Else, all messages will be printed.

    -h, --help
        Show this help message and exit.
"

# Define the default values for the variables
BACKUP_DESTINATION_DIR="$HOME/github-backup"
GITHUB_USER_ORG="Teidesat"
INCLUDE_REPOSITORIES=""
EXCLUDE_REPOSITORIES=""
ALL_BRANCHES=false
PULL_MODE="ff-only"
RECURSE_SUBMODULES=false
QUIET=false

# Initialize the git clone/pull arguments list
GIT_ARGS=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--backup-destination-dir)
            BACKUP_DESTINATION_DIR="$2"
            shift 2
            ;;
        -g|--github-user)
            GITHUB_USER_ORG="$2"
            shift 2
            ;;
        -i|--include_repositories)
            INCLUDE_REPOSITORIES="$2"
            shift 2
            ;;
        -e|--exclude_repositories)
            EXCLUDE_REPOSITORIES="$2"
            shift 2
            ;;
        -b|--all-branches)
            ALL_BRANCHES=true
            shift
            ;;
        -m|--pull-mode)
            PULL_MODE="$2"
            shift 2
            ;;
        -r|--recurse-submodules)
            RECURSE_SUBMODULES=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -h|--help)
            echo "$HELP"
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1"
            echo "$HELP"
            exit 1
    esac
done

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Error: git is not installed. Please install and configure it to use this script."
    exit 1
fi

# Check if GitHub CLI (gh) is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed. Please install and configure it to use this script:
    https://cli.github.com/manual/"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it to use this script."
    exit 1
fi

# Check if the backup destination directory exists, if not, create it
if [[ ! -d "$BACKUP_DESTINATION_DIR" ]]; then
    if ! $QUIET; then
        echo "Info: Creating backup destination directory: $BACKUP_DESTINATION_DIR"
    fi
    # Create the backup destination directory and check if it was successful
    if ! mkdir -p "$BACKUP_DESTINATION_DIR"; then
        echo "Error: Failed to create backup destination directory: $BACKUP_DESTINATION_DIR"
        exit 1
    fi
elif ! $QUIET; then
    echo "Info: Using existing backup destination directory: $BACKUP_DESTINATION_DIR"
fi

# Check if the provided GitHub user or organization exists
if ! gh api "/users/$GITHUB_USER_ORG" &> /dev/null && ! gh api "/orgs/$GITHUB_USER_ORG" &> /dev/null; then
    echo "Error: GitHub user or organization '$GITHUB_USER_ORG' does not exist."
    exit 1
fi

# Fetch the list of all GitHub repositories owned by the provided user or organization
if ! $QUIET; then
    echo "Info: Fetching repositories for GitHub user/organization: $GITHUB_USER_ORG"
    REPO_LIST=$(gh repo list "$GITHUB_USER_ORG" --limit 1000 --json name,sshUrl,defaultBranchRef --jq '.[]')
else
    REPO_LIST=$(gh repo list "$GITHUB_USER_ORG" --limit 1000 --json name,sshUrl,defaultBranchRef --jq '.[]' 2>/dev/null)
fi

# Check if also clone/pull submodules
if $RECURSE_SUBMODULES; then
    GIT_ARGS="$GIT_ARGS --recurse-submodules"
    if ! $QUIET; then
        echo "Info: Cloning submodules recursively."
    fi
else
    if ! $QUIET; then
        echo "Info: Not cloning submodules recursively."
    fi
fi

# Set the clone/pull verbosity based on the quiet mode of this script
if $QUIET; then
    GIT_ARGS="$GIT_ARGS --quiet"
else
    GIT_ARGS="$GIT_ARGS --verbose"
fi

# Change directory to the backup destination directory
if ! $QUIET; then
    echo "Info: Changing directory to backup destination: $BACKUP_DESTINATION_DIR"
fi
if ! cd "$BACKUP_DESTINATION_DIR"; then
    echo "Error: Failed to change directory to backup destination: $BACKUP_DESTINATION_DIR"
    exit 1
fi

# For every repository in the list, perform the following actions
# - If the repository is not cloned at the destination directory, clone it
# - If the repository is already cloned, pull the latest changes
for current_repo in $REPO_LIST; do

    # Extract the repository details from the JSON output
    REPO_NAME=$(echo "$current_repo" | jq -r '.name')
    REPO_URL=$(echo "$current_repo" | jq -r '.sshUrl')
    DEFAULT_BRANCH=$(echo "$current_repo" | jq -r '.defaultBranchRef.name')

    # Check if the repository should be included
    if [[ -n "$INCLUDE_REPOSITORIES" && ! "$REPO_NAME" =~ $INCLUDE_REPOSITORIES ]]; then
        if ! $QUIET; then
            echo "Info: Skipping non-included repository: $REPO_NAME"
        fi
        continue
    fi

    # Check if the repository should be excluded
    if [[ -n "$EXCLUDE_REPOSITORIES" && "$REPO_NAME" =~ $EXCLUDE_REPOSITORIES ]]; then
        if ! $QUIET; then
            echo "Info: Skipping excluded repository: $REPO_NAME"
        fi
        continue
    fi

    # Print the repository name if not in quiet mode
    if ! $QUIET; then
        echo "Info: Processing repository: $REPO_NAME"
    fi

    # Check if the repository is already cloned
    if [[ ! -d "$REPO_NAME" ]]; then
        if ! $QUIET; then
            echo "Info: Repository not found at $REPO_NAME."
        fi
        GIT_CLONE_ARGS="$GIT_ARGS"

        # Check if clone all branches
        if $ALL_BRANCHES; then
            GIT_CLONE_ARGS="$GIT_CLONE_ARGS --all"
            if ! $QUIET; then
                echo "Info: Cloning all branches of the repository from: $REPO_URL"
            fi
        else
            GIT_CLONE_ARGS="$GIT_CLONE_ARGS --single-branch"
            if ! $QUIET; then
                echo "Info: Cloning the default branch '$DEFAULT_BRANCH' of the repository from: $REPO_URL"
            fi
        fi

        # Clone the repository and check if it was successful
#        if ! git clone $GIT_CLONE_ARGS "$REPO_URL" "$REPO_NAME" 2>/dev/null; then
        if ! git clone $GIT_CLONE_ARGS "$REPO_URL" "$REPO_NAME"; then
            echo "Error: Failed to clone repository: $REPO_NAME"
            continue
        elif ! $QUIET; then
            echo "Info: Successfully cloned repository at $REPO_NAME"
        fi

    # Else if the repository is already cloned, pull the latest changes
    elif ! $QUIET; then
        echo "Info: Repository already exists at $REPO_NAME, pulling latest changes using mode: $PULL_MODE"
    fi
    GIT_PULL_ARGS="$GIT_ARGS"

    # Parse the pull mode and validate it
    case "$PULL_MODE" in
        ff-only)
            GIT_PULL_ARGS="$GIT_PULL_ARGS --ff-only"
            ;;
        rebase)
            GIT_PULL_ARGS="$GIT_PULL_ARGS --rebase=true"
            ;;
        merge)
            GIT_PULL_ARGS="$GIT_PULL_ARGS --rebase=false"
            ;;
        *)
            echo "Error: Unknown pull mode: $PULL_MODE. Valid options are: ff-only, rebase, merge."
            exit 1
            ;;
    esac

    # Change directory to the current repository
    if ! cd "$REPO_NAME"; then
        echo "Error: Failed to change directory to repository: $REPO_NAME"
        exit 1
    elif ! $QUIET; then
        echo "Info: Current working directory: $(pwd)"
    fi

    # Pull the latest changes from the remote repository
    if ! git pull $GIT_PULL_ARGS "$REPO_URL" 2>/dev/null; then
        echo "Error: Failed to pull changes for repository: $REPO_NAME. Please resolve any conflicts manually."
        exit 1
    elif ! $QUIET; then
        echo "Info: Successfully pulled changes for repository: $REPO_NAME"
    fi

    # Change directory back to the backup destination directory
    if ! cd -; then
        echo "Error: Failed to change to previous working directory."
        exit 1
    elif ! $QUIET; then
        echo "Info: Changed back to backup destination directory: $(pwd)"
    fi

done
