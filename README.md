# Klipper Github Backup & Restore Tool
Backup and restore your Klipper config to github

This tool gives you the ability to backup your existing klipper config or restore your existing config onto a fresh build of klipper. 
It is assumed that you have klipper installed before using this tool. 

There are two options to select from. 
1) Backup
2) Restore

## Instructions

Assuming you already have a Github account 

1. Create a new GitHub repository
2. Create a token for access to the repo (Settings--Developer--Personal Access Tokens)
3. SSH To the printer and run the commands below. Replace the values with your actual
   
 ```USERNAME, EMAIL, TOKEN AND REPOSITORY```

Git is a dependency for this script to run please make sure to install git if you have not already

`sudo apt-get install git -y`

To get started with this script navigate to your home folder on your device and down the script 

`wget -q https://raw.githubusercontent.com/m00seee/Klipper-Backup-Restore-tool/main/menu.sh`

Make the script executable 

`chmod +x menu.sh`

Now run the script for the first time `./menu.sh` and you will be prompted to input your Git Username, Email Address, Token and Repo URL.
**It is very important for the Repository URL that you DO NOT include the https://**

When you next run the script via `./menu.sh` or using the macro it will not prompt you for these details again.

To finish the installation it is recommended to reboot the device you have installed the script on.

#### You can choose to automate this backup process by calling the macro or the menu.sh script. This can be setup to run as a cron or even at the start/end of a print. I will leave this up to you. 

