# SFTP-Mounter
Automates mounting of an SFTP Share as a Local OR Network Disk on Windows systems.

## Instructions
1. Download script to a directory of your choice
2. Run Powershell (As Admin)
3. Enable script execution with powershell command below (substituting path as demonstrated):
> Unblock-File -Path '''Enter path manually OR drag and drop script into powershell window'''
5. Enter script path manually OR drag and drop script into powershell window
6. Add paramters _e.g. -hostname server0000.file-restore.net_ -- command should look like below:
> .\sftp_mounter.ps1 -hostname server0000.file-restore.net -username sftp000000 -password hunter2
7. RUN!


### Under Development:
* Support for iscsi / block devices.





https://user-images.githubusercontent.com/30591465/125978471-f4796b51-a570-46c6-bdd1-a8c8ba7660ea.mp4


