#!/bin/bash
# Configure a newly cloned git repo.

repodir="$1"
if [ ! -d "$repodir" ]; then
    echo "$repodir: does not exist!"
    exit 1
fi
if git -C "$repodir" show-ref -q refs/meta/config; then
    echo "Project is already provisioned, skipping init."
    exit
fi

set -eu
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"

ssh-gerrit() {
    echo "SSH: $@" >&2
    # Always use exit code 2 because failed connections fail with 255 which
    # makes ansible assume an unreachable host.
    ssh admin@localhost -p29418 -oStrictHostKeyChecking=no "$@" || return 2
}

# Wait for Gerrit SSH daemon to become available (try for at most 10 seconds).
ok=false
for ((i=0; i<10; i++)); do
    if ssh-gerrit "gerrit version" 2>/dev/null | grep -q "gerrit version "; then
        ok=true
        break
    fi
    sleep 1
done
if ! $ok; then
    echo "Cannot connect to Gerrit SSHd"
    exit 3
fi

# Create groups (if missing)
groups=$(ssh-gerrit "gerrit ls-groups -v")
[[ "$groups" == *Core\ Developers* ]] || ssh-gerrit "gerrit create-group 'Core Developers'"
[[ "$groups" == *Buildbots* ]] || ssh-gerrit "gerrit create-group 'Buildbots'"
ssh-gerrit "gerrit set-members 'Non-Interactive Users' -i Buildbots"

# Create buildbot user (ssh keys will be added later as needed).
# (Ignore error in case user already exists.)
ssh-gerrit "gerrit create-account wireshark-buildbot --email buildbot@localhost --full-name Buildbot -g Buildbots" || :

# echo ssh-rsa ... |
# ssh-gerrit gerrit create-account wireshark-buildbot --email buildbot@localhost --full-name Buildbot -g Buildbots --ssh-key -

# Groups
ssh-gerrit "gerrit ls-groups -v" |
awk 'BEGIN{FS=OFS="\t";printf "%-40s\tGroup Name\n#\n", "# UUID"}{print $2, $1}' > groups

# Expect at least five lines: header, separator, three groups
if ! [ $(wc -l < groups) -gt 5 ]; then
    echo ""
    exit 1
fi

# project.config
cat <<'EOF' > project.config
[project]
	description = The Wireshark network protocol analyzer

# https://code.wireshark.org/review/Documentation/config-labels.html
[label "Code-Review"]
	function = MaxWithBlock
	copyMinScore = true
	value = -2 Do not submit
	value = -1 I would prefer that you didn't submit this
	value =  0 No score
	value = +1 Looks good to me, but someone else must approve
	value = +2 Looks good to me, approved
	defaultValue = 0
	copyAllScoresOnTrivialRebase = true
	copyAllScoresIfNoCodeChange = true

[label "Verified"]
	defaultValue = 0
	#function = MaxWithBlock
	function = NoBlock
	value = -1 Fails
	value =  0 No score
	value = +1 Verified
	copyAllScoresOnTrivialRebase = true
	copyAllScoresIfNoCodeChange = true

[label "Petri-Dish"]
	function = NoBlock
	value = -1 Skip test
	value =  0 No score
	value = +1 Test
	defaultValue = 0
	copyAllScoresOnTrivialRebase = true
	copyAllScoresIfNoCodeChange = true

[access "refs/heads/*"]
	label-Verified = -1..+1 group Buildbots
	label-Verified = -1..+1 group Core Developers
	label-Petri-Dish = -1..+1 group Core Developers
	label-Code-Review = -2..+2 group Core Developers
	submit = group Administrators
	submit = group Core Developers
	forgeCommitter = group Core Developers
	abandon = group Core Developers

# allow forgery for tags
[access "refs/tags/*"]
	forgeAuthor = group Administrators
	forgeCommitter = group Administrators

# http://wiki.wireshark.org/Development/Workflow
[submit]
	action = cherry pick
EOF

# Create new tree at refs/meta/config
git init
git config --local user.name 'Gerrit'
git config --local user.email 'gerrit@localhost'
git add groups project.config
git commit -m 'Initial project config'
git push "$repodir" HEAD:refs/meta/config

# Flush at least project cache.
ssh-gerrit "gerrit flush-caches --all"

echo DONE
