ftp.ccc.de sync skript
======================

This script is used to sync the darmstadt mirror of ftp.ccc.de against the master media.ccc.de.
You need a ssh-key and a sftp-password in addition to this skript if you want to start a new ftp.ccc.de mirror.

Please contact ftpmaster@lists.ccc.de or join #ftpmaster on hackint.org in case of questions.

The script should be run by a cronjob in regular intervals, like once every hour.


## installation
### Requirements
This scripts need rsync, lftp (with an sftp-module) and tree installed.
On debian, the following packets need to be installed:

* lftp
* rsync
* tree

To send out emails in case of errors, the host should have a proper email config.

### Configuration
#### lftp 
The user who runs this script needs the following in its ~/.lftp/rc:
`set sftp:connect-program "ssh -a -x -i PATH-TO-SSH-KEY"`
this will tell lftp where the keyfile for sftp login is located.

### Configuration file

Rename default.config to your local configuration.
`mv default.config local.config`
Edit the path to your local.config in the script.
Then change the variables inside the local.config to suit your needs.
