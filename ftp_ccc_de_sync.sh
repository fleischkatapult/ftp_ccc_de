#!/usr/bin/env bash

# Description: Upload our stuff to master, then sync back changes from master.
# Uses a lockfile so only one instance can run.
# In case of an error, run with -f to clean up
# Run with -v to get verbose output to stdout
# By default stuff gets written to syslog



#### 
# Make sure the script exits on unset variables and on error 
set -o nounset
set -e


# change the default config name to your local configuration
configfile=/path/to/your/default.config

### No changes needed below

# Load config
if [ ! -f "${configfile}" ]
then
    echo "No config at ${configfile} found"
    exit 1
fi
source ${configfile}


#TODO: check for target, whether it is actually a directory!

#display usage
usage () {
  cat << EOF
  usage: $0 [-f][-v]
    -f      force, remove lock file first
    -v      verbose, direct output to stdout
EOF
  exit
}


# parse the arguments
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
	echo "ftp lock is older than 120 minutes. please check" | mail -s "potential ftp error" ${CONTACTEMAIL}
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


#Mirror FTP-Master, exclude our own paths (mrmcd, c-radar)
# exclude also files computed locally, like INDEX, INDEX.gz and TREE. NEW is sync from ftpmaster

RSYNCVERBOSE=""

#If verbose is set, give us progress and verbose stuff!
if [ -n "$VERBOSE" ]; then
    RSYNCVERBOSE="--progress -v"
fi

rsync ${RSYNCVERBOSE} --password-file=${RSYNCMASTERPWFILE} --exclude ".*" --exclude "lost+found" --exclude INDEX.gz --exclude "events/mrmcd" --exclude "broadcast/c-radar" --exclude "INDEX.gz" --exclude "INDEX" --exclude "TREE" -rltzxa --partial ${RSYNCMASTER} ${TARGET}
## TODO: readd del

# Create Tree, INDEX, INDEX.gz 
# NEW is synced from upstream

cd ${TARGET}
tree --noreport > TREE
find ./ -type f | sed "s/.\///" | sort > INDEX
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

