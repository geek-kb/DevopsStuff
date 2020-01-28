## SSH auto configuration tool for passworded machine


This tool runs through a list of ip's, delimited by comma and generates a .ssh/config block for each server.

In the next step, it ssh's to each machine and copies the local ssh public key to each one of the machines.

At the end of the run, you'll be able to connect to each machine like so:

ssh IP_ADDR

without the need to supply a user or a password to connect.

***

Running the script will backup your current ~/.ssh/config file.

The script has been tested on both MacOS Mojave and Fedora but should work with any Python 2 installed machine.

### Installation:
Install the required python libraries like so:

`pip install -r requirements.txt`

### Usage:
`./ssh_config.py`


