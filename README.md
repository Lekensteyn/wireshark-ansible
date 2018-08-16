# ansible configuration for Wireshark
This repository contains an ansible configuration to setup a private gerrit
instance, buildbot master and buildbot workers for testing purposes.

Compared to the current (May 2017) buildbot setup as active on
https://buildbot.wireshark.org/petri-dish/, this setup uses buildbot 0.9
(different UI) and a builders configuration which changes the three sequential
Debian/GCC/Clang builds into three parallel builds.

Roles:

 - gerrit-servers: private Gerrit instance. Initial user is admin, the admin SSH
   key can be found in the homedir of user "gerrit".
 - buildbot-masters: buildbot master that will trigger on changes from the first
   gerrit-servers host.
 - buildbot-workers: one or more buildbot workers which connect to the master.

Security notes:

 - General approach: do not log or leak secrets.
 - admin SSH key: automatically generated on gerrit. Used only on the master.
 - buildbot master SSH key: automatically generated on master, public key is
   installed on gerrit (needed for watching for changes and posting comments).
 - buildbot worker password: automatically generated on master, copied to
   workers.
 - Workers fetches the git repo from the Gerrit server over anonymous HTTP.
 - Assumes network between master and workers is trusted (traffic is not
   protected).

Tested with minimal Ubuntu 16.04 QEMU VMs in a bridged network.

## Usage
Copy the `hosts` file and modify it according to your setup. Ideally the gerrit,
master and worker hosts are all separate, but for testing purposes they can be
the same.

If you have a minimal Ubuntu 16.04 installation (with just Python 3) and a
password-less sudo user, then you need to provision it once with:

    ansible-playbook -i hosts init.yml

After that you can configure the other hosts with:

    ansible-playbook -i hosts site.yml

If you decide to add a new worker later, you can limit the run to some hosts:

    ansible-playbook -i hosts site.yml -l master,worker1

### Buildbot only
To use an existing git repo (without Gerrit), use something like:

    ansible-playbook -i hosts site.yml -l master,worker1 \
      -e gerrit_host= \
      -e git_url=https://code.wireshark.org/review/wireshark

## Notes
Adding a user to the Core Developers group can be done from the Gerrit host:

    sudo su - gerrit
    ssh admin@localhost -p29418 "gerrit set-members 'Core Developers' -a Lekensteyn"

When installing gerrit after the master, remove a cached key to ensure that the
buildbot user in gerrit is updated:

    rm buildbot-pubkeys/master.pub

## TODO
 - Add macOS and Windows workers.
 - Use https for git URL (should also consider reverse proxy).
 - Integrate changes into buildbot.wireshark.org infrastructure.
 - Test with other environments (e.g. provision old laptop as worker).
 - Prepare public demo (currently I only have a proxied hack available).
 - Upgrade logic for Gerrit.
 - Cleaning up TODOs.
 - ...
