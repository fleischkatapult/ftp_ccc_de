ftp.ccc.de sync skript
======================

This script is used to sync the darmstadt mirror of ftp.ccc.de against the master media.ccc.de

You need a ssh-key and a sftp-password in addition to this skript if you want to start a new ftp.ccc.de mirror.

Please contact ftpmaster@lists.ccc.de or join #ftpmaster on hackint.org in case of questions


# Description: Upload our stuff to master, then sync back changes from master.
# Uses a lockfile so only one instance can run.
# In case of an error, run with -f to clean up
# Run with -v to get verbose output to stdout
# By default stuff gets written to syslog


# For installation:
# this scripts need rsync, lftp (with an sftp-module) and tree installed
# the user who runs this script need the following in its ~/.lftp/rc:
#     set sftp:connect-program "ssh -a -x -i PATH-TO-SSH-KEY"
#     this will tell lftp where the keyfile for sftp login is located




Change the following variables to suit your needs:


#Change so it points to your local rsync
rsync=/usr/bin/rsync
#Lock file to make sure we only run one instance at a time. Needed for initial / long syncs or slow links
LOCK_FILE=/var/tmp/rsync-media.lock

#The master node to sync with
MASTER=upload.media.ccc.de

#TARGET has to end with a slash! Change it to suit you local installation
TARGET=/mnt/ftp/ftp.ccc.de/
#Your local user/group for file permissions
FTPUSER=web012
FTPGROUP=web012
