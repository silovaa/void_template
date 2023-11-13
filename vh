#! /bin/sh

#LOCAL_REPO="${XDG_CACHE_HOME=${HOME?}/.cache}/vh/void-packages"
LOCAL_REPO="/tmp/void-packages"
CONFIG_DIR="${XDG_CONFIG_HOME=${HOME?}/.config}/vh"
CFG_FILE="${CONFIG_DIR}/config"
export XBPS_DISTDIR="$LOCAL_REPO"

# Read / generate config

if [ ! -f "$CFG_FILE" ]; then
    echo "You don't have a config file in $CFG_FILE"
    echo "We will create one for you"
    # Check if $EDITOR is set
    # If not, ask for it
    # If yes, open $CFG_FILE in $EDITOR
    if [ -z "$EDITOR" ]; then
        echo "What is your preferred editor?"
        read -r EDITOR
    fi
    mkdir -p "$CONFIG_DIR"
    cat << EOF > "$CFG_FILE"
export EDITOR="$EDITOR"

VOID_PACKAGES_UPSTREAM="https://github.com/void-linux/void-packages"

# Where is your void-packages fork URL? (leave empty to create a local repo)"
VOID_PACKAGES_FORK=""
EOF
    echo "Config file created in $CONFIG_DIR."
    $EDITOR "$CFG_FILE"
    exit
fi

eval $(sed -r '/[^=]+=[^=]+/!d;s/\s+=\s/=/g' "$CFG_FILE")

GIT_OPTS="--git-dir=$LOCAL_REPO/.git --work-tree=$LOCAL_REPO"

red() {
  printf '\033[1;31m%s\033[0m\n' "$@"
}

green() {
  printf '\033[1;32m%s\033[0m\n' "$@"
}

set_up_repo() {
    if [ ! -d "$LOCAL_REPO" ]; then
        if [ -z "$VOID_PACKAGES_FORK" ]; then
            echo "Void-packages fork not specified in config file. Creating local repo instead."
            git init "$LOCAL_REPO"
        else
            echo "Cloning void-packages fork from $VOID_PACKAGES_FORK"
            git clone $VOID_PACKAGES_FORK "$LOCAL_REPO"
        fi
    fi
}

update() {
    # get branch as argument. If not specified, use master
    BRANCH="${1:-master}"
    echo "Updating branch $BRANCH of local repo at $LOCAL_REPO"
    cd $LOCAL_REPO
    git checkout -q $BRANCH
    [ -z "$(git remote -v | grep github.com/void-linux/void-packages)" ] && git remote add upstream $VOID_PACKAGES_UPSTREAM
    git fetch -q upstream master
    git rebase upstream/master &&
      green "Repo updated." ||
        (red 'Failed to update repo. Please do it manually.';
         red "run: $0 -c git rebase upstream/master")
}

# select a branch using fzf
update_interactive() {
    update $(git branch -r | grep -v HEAD | fzf --height=50% --prompt="Select a branch to update: ")
}

continue_or_exit() {
    echo "Continue? [y/N] "
    read -r yn
    case $yn in
        [Yy]* ) return 0;;
        * ) exit;;
    esac
}

contribute() {
    echo "New branch name"
    read -r $NEW_BRANCH
    git $GIT_OPTS checkout -b $NEW_BRANCH upstream/master
}

prcheckout () {
    local jq_template pr_number
    jq_template='"'\
'#\(.number) - \(.title)'\
'\t'\
'Author: \(.user.login)\n'\
'Created: \(.created_at)\n'\
'Updated: \(.updated_at)\n\n'\
'\(.body)'\
'"'
    # gh search prs --repo=void-linux/void-packages -L 1000

    pr_number=$(
    cd $LOCAL_REPO
    gh api 'repos/:owner/:repo/pulls' |
    jq ".[] | $jq_template" |
    sed -e 's/"\(.*\)"/\1/' -e 's/\\t/\t/' |
    fzf \
      --with-nth=1 \
      --delimiter='\t' \
      --preview='echo -e {2}' |
    sed 's/^#\([0-9]\+\).*/\1/'
  )

  echo "$pr_number"
  if [ -n "$pr_number" ]; then
    cd $LOCAL_REPO
    gh pr checkout "$pr_number"
  fi
}

help() {
    cat << EOF
Usage: $0 <package>

    <package>
         The name of the package to install.

    -u,  --update <branch>
         Update the specified branch of the local repo. If not specified, use master.
            If the branch doesn't exist, it will be created.

    -ui, --update-interactive
         Choose a branch to update interactively using fzf and update it.

    -e,  --edit
         Open the package's template file in your editor.

    -c, --command <command>
        Run the specified command in the void-packages repo. If no command is
        specified, cd to the void-packages repo and open a shell.

    -h, --help
        Show this help message.

    -l, --list
        List all packages in the local repo.


EOF
    exit
}

set -x
# main()
[ -z "$1" ] && help
case "$1" in
    --add-vur  | -a ) # ask name and url, and pull it into a branch
        echo "Name of the VUR"
        VUR_BRANCHES=$(git $GIT_OPTS branch -a -l "VUR/*")
        VUR_BRANCH=$(echo "$VUR_BRANCHES" | cut -c 3- | fzf --with-nth=1 --delimiter='\t' --print-query)
        # If VUR_BRANCH does not start with VUR/, add it.
        test "${VUR_BRANCH#VUR/}" != "$VUR_BRANCH" || VUR_BRANCH="VUR/$VUR_BRANCH"

        echo $VUR_BRANCH

        echo "URL of the VUR"
        read -r VUR_URL
        BRANCH="VUR/$VUR_NAME"
        set -x
        git $GIT_OPTS checkout -b $BRANCH
        git $GIT_OPTS fetch -v $VUR_URL master
        exit
        ;;
	--update   | -u ) set_up_repo; update $2; exit;;
	--update-interactive   | -ui ) set_up_repo; update_interactive; exit;;
	--edit     | -e ) xnew "$2" 2> /dev/null || ${EDITOR} "$LOCAL_REPO"/srcpkgs/"$2"/template; exit;;
	--xbps-src | -x ) "$LOCAL_REPO"/xbps-src $2; exit;;
	--command  | -c )
        cd $LOCAL_REPO
        test -z "$2" && $SHELL && exit
        shift; "$@"; exit;;
	--pr-checkout | -p) prcheckout; exit;;
	--help     | -h ) help; exit;;
esac

package="$1"
# Build and install
less "$LOCAL_REPO"/srcpkgs/"$package"/template
continue_or_exit
"$LOCAL_REPO"/xbps-src pkg "$package"
set -x
xi -R "$LOCAL_REPO"/hostdir/binpkgs "$package"
