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
 - Assumes network between master and workers is trusted (traffic is not
   protected).

Tested with minimal Ubuntu 16.04 preseeded images in a bridged network.

## TODO
 - Add macOS and Windows workers.
 - Use https for git URL (should also consider reverse proxy).
 - Integrate changes into buildbot.wireshark.org infrastructure.
 - ...
