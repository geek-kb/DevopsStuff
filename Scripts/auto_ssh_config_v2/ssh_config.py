#!/usr/bin/python2
# Script by Itai Ganot 2020

# Imports
from os.path import expanduser, isfile
import subprocess
import tarfile
import urllib2
import os
import getpass
from datetime import datetime
from termcolor2 import colored

# Variables
user = 'USERNAME'
password = 'PASSWORD'
home = expanduser("~")
sshpass_version = '1.05'
ip_list = ["First IP", "Second IP", "Etc..."]
sshpass_filename = 'sshpass-{}.tar.gz'.format(sshpass_version)
url = 'http://downloads.sourceforge.net/project/sshpass/sshpass/{}/{}'.format(sshpass_version, sshpass_filename)
now = datetime.now()
dt_string = now.strftime("%d-%m-%Y_%H-%M-%S")

# Functions
def backupSshConfig():
    if isfile('{}/.ssh/config'.format(home)):
        print colored('Backing up your ssh config file', 'green')
        os.system('cp {}/.ssh/config {}/.ssh/config.bak_{}'.format(home, home, dt_string))
    else:
        print colored('No configuration file found, not performing backup', 'yellow')

def downloadSshpass(url):
    with open(home+'/'+sshpass_filename, 'wb') as file:
       with urllib2.urlopen(url) as filedata:
              file.write(filedata.read())

def installSshpass(file):
    print colored('In order to install sshpass your laptop user password is required, please enter it now', 'yellow')
    passwd = getpass.getpass()
    with tarfile.open(file, "r:gz") as tar:
        tar.extractall()
    print colored('Now installing sshpass!', 'yellow')
    os.system('''
    cd sshpass-{}
    ./configure
    make
    echo {} | sudo -S make install
    '''.format(sshpass_version, passwd))

def sshConfig(ip_list):
    print colored('Now configuring your {}/.ssh/config file'.format(home), 'green')
    with open(home+'/.ssh/config', 'a+') as file:
        for ip in ip_list:
            file.write("Host {}\nUser {}\nHostName {}\nStrictHostKeyChecking=no\nConnectTimeout=1\n".format(ip, user, ip))
            file.write('\n')

def sshCopyId(ip_list, password):
    for ip in ip_list:
        print colored('#######################################################', 'yellow')
        print colored('Copying your personal key to ip: {}'.format(ip), 'green')
        os.system('sshpass -p {} ssh-copy-id -f {}'.format(password, ip))

def cleanGarbage():
    os.system('rm -f {}/{}'.format(home, sshpass_filename))
    os.system('rm -rf sshpass-{}'.format(sshpass_version))

def main():
    cmd = 'which sshpass > /dev/null 2>&1'
    try:
        subprocess.check_call(cmd, shell=True)
        print colored('sshpass is installed!', 'green')
    except subprocess.CalledProcessError as e:
        print colored('sshpass not installed! installing...', 'red')
        downloadSshpass(url)
        installSshpass(home+'/'+sshpass_filename)

    backupSshConfig()
    sshConfig(ip_list)
    sshCopyId(ip_list, password)
    cleanGarbage()

# Code
if __name__ == '__main__':
    main()
