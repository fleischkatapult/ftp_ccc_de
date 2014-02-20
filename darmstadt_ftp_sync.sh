#!/bin/bash
# Description: Upload our stuff to master, then sync back changes from master.
# Uses a lockfile so only one instance can run.
# In case of an error, run with -f to clean up
# Run with -v to get verbose output to stdout
# By default stuff gets written to syslog

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


# the account to send our files to the ftp master via sftp is defined in UPLOADACCOUNT
# the account to receive changes via rsync is defined in the RSYNCMASTER variable
RSYNCMASTER=rsync://darmstadt@koeln.media.ccc.de/ftp
RSYNCMASTERPWFILE=darmstadt_media_rsync_pw

#TODO: check for target, whether it is actually a directory!

### No changes needed below


usage () {
  cat << EOF
  usage: $0 [-f][-v]
    -f      force, remove lock file first
    -v      verbose, direct output to stdout
EOF
  exit
}



while getopts "fvh" opt; do
  case "$opt" in 
    v) VERBOSE=1;;
    f) rm -f "$LOCK_FILE";;
    *) usage;;
  esac
done


# CRON: silent unless VERBOSE

#if verbose not set, mail!
if [ -z "$VERBOSE" ]; then
  MAILTO=""
  exec >/dev/null 2>&1
fi


#check for the lockfile
if [ -f "$LOCK_FILE" ]; then
  
  /usr/bin/logger -t "$(basename $0)[$$]" "Lock file '${LOCK_FILE}' exists. Please check if another rsync is running. Test sync: 'sudo -u media-sync $0 -fv'"
  echo "${LOCK_FILE}' exists. Please check if another rsync is running."
  if test `find "$LOCK_FILE" -mmin +120`; then
	echo "ftp lock is older than 120 minutes. please check" | mail -s "potential ftp error" bios@darmstadt.ccc.de
  fi
  exit
fi


# start sync
echo "create lock file"
touch "$LOCK_FILE"


echo "Starting FTP Sync" | logger -t "ftpsync"

#fix permissions before starting the upload
chmod -R g+rwX ${TARGET}broadcast/c-radar
chmod -R o+rX ${TARGET}broadcast/c-radar
chown -R ${FTPUSER}:${FTPGROUP} ${TARGET}events/mrmcd


echo "c-radar FTP Sync" | logger -t "ftpsync"


lftp -u chaosdarmstadt,test -p 2222 sftp://upload.media.ccc.de -e "mirror -Rc --delete ${TARGET}broadcast/c-radar/ ftp/broadcast/c-radar/; exit"


echo "mrmcd FTP Sync" | logger -t "ftpsync"

lftp -u chaosdarmstadt,test -p 2222 sftp://upload.media.ccc.de -e "mirror -Rc --delete ${TARGET}events/mrmcd/ ftp/events/mrmcd/; exit"

#Backup des alten TREEs
cp ${TARGET}TREE /var/tmp/ftp_INDEX
# und download des mirrorcontents

#Mirror FTP-Master, exclude our own paths (mrmcd, c-radar)
# exclude also files computed locally, like INDEX, INDEX.gz and TREE. NEW is sync from ftpmaster

#alt: rsync mit ssh rsync -e 'ssh -4 -i /root/.ssh/media.ccc.key.id_rsa -p 2222' --exclude ".*" --exclude "lost+found" --exclude INDEX.gz --exclude "events/mrmcd" --exclude "broadcast/c-radar" --exclude "INDEX.gz" --exclude "INDEX" --exclude "TREE" --del -rltzxaP ${RSYNCMASTER} ${TARGET}

RSYNCVERBOSE=""

#If verbose is set, give us progress and verbose stuff!
if [ -n "$VERBOSE" ]; then
    RSYNCVERBOSE="--progress -v"
fi

rsync ${RSYNCVERBOSE} --password-file=${RSYNCMASTERPWFILE} --exclude ".*" --exclude "lost+found" --exclude INDEX.gz --exclude "events/mrmcd" --exclude "broadcast/c-radar" --exclude "INDEX.gz" --exclude "INDEX" --exclude "TREE" -rltzxa --partial ${RSYNCMASTER} ${TARGET}
## TODO: readd del

# Create Tree, INDEX, INDEX.gz and NEW
# Update: We sync NEW from ftpmaster

cd ${TARGET}
tree --noreport > TREE
find ./ -type f | sed "s/.\///" | sort > INDEX
#diff /var/tmp/ftp_INDEX  ${TARGET}INDEX -U 0 | grep -Ev '^[+]{3,3}' | grep -Ev '^[-]{3,3}' | grep -Ev '^@@' > NEW
#gzip -1 -c INDEX > INDEX.gz
find . -type f \! -name .\* -printf "%T@ %s %p\n" | grep -v "./INDEX.gz" | sort -n | gzip -1 > INDEX.gz
echo "Successfull FTP Sync" | logger -t "ftpsync"

if [ -z "$VERBOSE" ]; then
	echo "FTP Run done, fixing permissions"
fi

#fix file permissions

echo "Fixing file permissions" | logger -t "ftpsync"


chown ${FTPUSER}:${FTPGROUP}  -R ${TARGET}
chmod -R o+rX ${TARGET}
chmod -R g+rX ${TARGET}
chown :c-radar -R ${TARGET}broadcast/c-radar
chmod -R g+rwX ${TARGET}broadcast/c-radar
chmod -R o+rX ${TARGET}broadcast/c-radar

echo "FTP Sync done, removing lockfile" | logger -t "ftpsync"


# cleanup
echo "remove lock file"
rm -f "$LOCK_FILE"

