# Overview
Solution to backup VMs on ESXi hypvervisor.  The script will first snapshot a running VM, create a local thin disk backup,  remove the snapshot, and copy the backup to a remote server for redundancy.

# Alternatives
The ubiquitous and well known Veeam solution is probably a better off solution for enterprise use although such an approach would incur license cost (Veeam and Windows) and additional compute.

# Example Usage
Read 'Backup Server Setup' section below before proceeding.

## Normal VMs
* Download both backup and scripts folder into the datastore.  For example `/vmfs/volumes/datastore1`.
* Assuming the name of a VM is 'Corp Production Web Server' and the remote backup server IP is 10.1.6.7, run the following command:
```bash
/vmfs/volumes/datastore1/scripts/backup-vm.sh "Corp Production Web Server" scp 10.1.6.7 /vmfs/volumes/datastore1
``` 
* This will create a local backup copy under the 'backup' folder, and also on the remote server.

## GNS3 VMs
For GNS3 VM it comes with two disks so would both needs to be cloned and copied.  Run the corresponding script instead.  For example:
```bash
/vmfs/volumes/datastore1/scripts/backup-vm-gns3.sh "GNS3 - 2.2.7" scp 10.1.6.7 /vmfs/volumes/datastore1
``` 

## Verification
Check backup log files.
```bash
cat "/vmfs/volumes/datastore1/backup/CorpProductionWebServer.log"
cat "/vmfs/volumes/datastore1/backup/GNS3-2.2.7.log"
```

Check backed up VMs.
```bash
ls -ltr "/vmfs/volumes/datastore1/backup"
```

# Backup Server Setup
## Background
ESXi doesn’t permit users not in the Administrator role to login.  There aren’t any “su” or “sudo” shell commands either so you can’t login as root and do the transfer as the backup user.  This means we can’t log in from the backup server to pull backups without granting the backup user the Administrator role, and we can’t push backups to the backup server.  The only way to do the transfer is to use 'root' or another user with Administrator role.

## Use RSA Public Key of Root User on ESXi
Referring to the following article we can see some information specific to ESXi hosts such as the location for the ssh-keygen tool.
https://kb.vmware.com/s/article/1002866
### Step 1 - Generate RSA Keys
```bash
[root@esxi6prim:~] pwd
/
[root@esxi6prim:~] ls -ltr /.ssh
total 4
-rw-r--r--    1 root     root           394 Mar 29 03:21 known_hosts
[root@esxi6prim:~]
[root@esxi6prim:~] /usr/lib/vmware/openssh/bin/ssh-keygen -t rsa
Generating public/private rsa key pair.
Enter file in which to save the key (//.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in //.ssh/id_rsa.
Your public key has been saved in //.ssh/id_rsa.pub.
The key fingerprint is:
d7:a:53:84:b6:cc:32:cf:89:b0:b3:e:74:73:81:20 root@esxi6prim
The key's randomart image is:
+--[ RSA 2048]----+
|         ..      |
|        o.       |
|E .    + ..      |
| . ...o +. .     |
|    .o.*S.. .    |
|    o ..++ .     |
|  . oo.   .      |
| . o.o           |
|  ...            |
+-----------------+
[root@esxi6prim:~] ls -ltr /.ssh
total 12
-rw-r--r--    1 root     root           394 Mar 29 03:21 known_hosts
-rw-r--r--    1 root     root           396 Mar 29 03:35 id_rsa.pub
-rw-------    1 root     root          1679 Mar 29 03:35 id_rsa
```
### Step 2 - Copy Root Key to Backup Server
#### Normal Linux Server
```bash
/home/backup/.ssh/authorized_keys
```
#### ESXi Server
Per https://kb.vmware.com/s/article/1002866 the authorized_keys file on ESXi is at the following location instead:
```bash
/etc/ssh/keys-<username>/authorized_keys
```

# License
Apache License 2.0