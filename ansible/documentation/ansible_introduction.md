# Ansible


## Required vocabulary

**inventory**:

Ansible works against multiple systems in your infrastructure at the same time. It does this by selecting portions of systems listed in Ansible’s inventory file, which defaults to being saved in the location `/etc/ansible/hosts`. You can specify a different inventory file using the `-i <path>` option on the command line.

An example of an inventory file can be found below.

More information can be found [here](https://bit.ly/2X68Oc5).

**modules:**

A module is a reusable, standalone script that Ansible runs on your behalf, either locally or remotely. Modules interact with your local machine, an API, or a remote system to perform specific tasks like changing a database password or spinning up a cloud instance.

Example of a module: yum, shell, etc...

More information can be found [here](https://bit.ly/3jQI4Gb).

**playbooks:**

Playbooks are Ansible’s configuration, deployment, and orchestration language. They can describe a policy you want your remote systems to enforce or a set of steps in a general IT process.

Example of a playbook: monitoring.yml.

More information can be found [here](https://bit.ly/310zUT9).

**roles:**

An Ansible role is an independent component which allows the reuse of common configuration steps. Ansible role has to be used within the playbook. Ansible role is a set of tasks to configure a host to serve a certain purpose like configuring a service. Roles are defined using YAML files with a predefined directory structure.

Example for a role: consul-client, node-exporter

More information can be found [here](https://bit.ly/2X6KzdD).

**facts:**

Ansible facts are a way of getting data about remote systems for use in playbook variables. Usually, these are discovered automatically by the setup module in Ansible. Users can also write custom facts modules.

Example for a fact: `ansible_default_ipv4.address`

More information can be found [here](https://bit.ly/39Ec3MX).


**If Ansible modules are the tools in your workshop, playbooks are your instruction manuals, and your inventory of hosts are your raw material.**


# How does Ansible work?

Ansible works by connecting to your nodes and pushing out small programs, called "Ansible Modules" to them. These programs are written to be resource models of the desired state of the system. Ansible then executes these modules (over SSH by default) and removes them when finished.

Your library of modules can reside on any machine, and there are no servers, daemons, or databases required. Typically you'll work with your favorite terminal program, a text editor, and probably a version control system to keep track of changes to your content.

## There are two ways to use Ansible:

### Using Ansible Ad-Hoc commands:

```
ansible affected_group [-i inventory (optional)] -m module [ -a arguments (optional)]
```

Example of an inventory file:

```
[test]
ansible.company.com

[slaves]
agent-c6-01.node.company.consul
agent-c6-02.node.company.consul
agent-c6-03.node.company.consul
```

Example of an ad-hoc command with an explicit inventory file:

```
ansible slaves -i inventory.file -m yum -a 'name=httpd state=latest'
```

It is not mandatory to use an explicit inventory file as there's a dynamic inventory configured that can be accessed from the Ansible server (ansible.company.com) but it's important to know how Ansible ad-hoc commands work.

Another reason to know it is if you want to work on a group of servers that is not part of the dynamic inventory ordering, then you just add the relevant servers to your inventory file and use it.

Looking at the above example, you can see how I chose to effect the slaves group from the inventory making sure that httpd is installed with the latest version.

If I were to run that command from the Ansible server, I'd run there:

```
ansible slaves -m yum -a 'name=httpd state=latest'
```

You can see that I haven't provided an inventory file, that is because there's a pre-configured inventory file in `/etc/ansible/ansible.cfg`:

```
[defaults]
inventory      = ~/consul_io.py
```
The above configuration tells Ansible to look for its inventory file in root's home folder - a file called `consul_io.py` which is consul's dynamic inventory script that acts just like a regular inventory but it's dynamic.


### Using playbooks:

Ansible playbooks allow you to run a set of tasks rather than one simple task at a time and allow you to manage your tasks/policies using a source control tool.

For example, let's say that I want to add monitoring to a newly created machine, I'll need to install and configure both consul-client and node-exporter roles on that machine, so I've already created such a playbook in advance, monitoring.yml:

```
---
# Use this playbook to install consul-client and node-exporter on
# Centos 6/7 machines.
- hosts: localhost
  vars:
    #ansible_python_interpreter: /usr/bin/python2
    ansible_user_shell: /bin/bash
  gather_facts: true
  roles:
    - consul-client
    - node-exporter
```

To run it, I'll SSH to the server I wish to configure, browse into the DevOps repo directory and into ansible directory inside `devops/ansible` and run:

```
ansible-playbook monitoring.yml
```

Ansible will go through the playbook and will run all the included roles in descending order.


###### Written by Itai Ganot, lel@lel.bz
