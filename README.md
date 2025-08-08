# GitHub Backup Script

This script is designed to back up the GitHub repositories from the provided user or organization to a local directory.

It uses the GitHub CLI tool to get the list of available repositories and then clones/pulls them to the specified local directory.

Ensure you have the requirements listed below installed and the necessary permissions to access the repositories you want to back up.

If first time running git pull, you may need to set up your SSH keys or authenticate with GitHub, follow the
 instructions at: https://docs.github.com/en/authentication/connecting-to-github-with-ssh

## Features
- Clones all repositories from a specified user or organization.
- Pulls updates for existing repositories.
- Supports both public and private repositories (requires authentication).
- Can include or exclude specific repositories based on patterns.
- Supports syncing all branches or just the default branch.
- Can handle submodules if specified.
- Provides options for different pull modes (fast-forward, rebase, merge).
- Quiet mode to suppress output messages.
- Can be run on a schedule using external tools like cron.

## Requirements
- Git
- GitHub CLI
- JQ (for JSON parsing)

## Usage

```bash
bash ./sync-from-github.sh [OPTIONS]
```

## Example

```bash
bash ./sync-from-github.sh --backup-destination-dir ~/github-backup --github-user Teidesat --branch all
```

## Options

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
