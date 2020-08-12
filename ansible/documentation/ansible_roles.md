# Working with Ansible roles

It's usually not necessary to write your roles as you can probably find whatever you might need in [Ansible Galaxy](https://bit.ly/30eFH8B) which is Ansible's official repository.

If you decide to write your role after all, then continue.

-------------------

To create a new role, a specific directory structure should be created.

Luckily, you don't have to remember this structure and you can run a command that creates it for you:

```
ansible-galaxy init role_name
```

Running the above command creates the following directory structure and example files:

![ansible directory structure](../screenshots/role_dir_structure.png)


**tasks directory**:

This is the most important directory.

When each role is loaded, Ansible will look for a `main.yml` file in the role's `tasks` directory.

In the `main.yml` file, you can directly place the tasks you want the role to run or better, divide the tasks to sub-tasks and load them from the `main.yml` file.

Example to a `main.yml` file that directly contains tasks:

```
---
# tasks file for filebeat

- name: check if elasticsearch repo is configured
  stat: path=/etc/yum.repos.d/elasticsearch.repo
  register: elastic_repo_stat

- name: configure elasticsearch repo
  block:
  - name: import elasticsearch GPG key
    rpm_key:
      state: present
      key: https://artifacts.elastic.co/GPG-KEY-elasticsearch
  - name: create elasticsearch repo file
    template:
      src: elasticsearch.repo.j2
      dest: /etc/yum.repos.d/elasticsearch.repo
      owner: root
      group: root
      mode: '0644'
  when: not elastic_repo_stat.stat.exists
.
.
.
```

Example to a `main.yml` file that calls to sub task files:

```
---
# tasks file for common
- name: python installation on centos 6 machines
  block:
  - import_tasks: python2_centos6.yml
  - import_tasks: python3_centos6.yml
  when: ansible_distribution_major_version == "6"
- import_tasks: python.yml
  when: ansible_distribution_major_version == "7"
- import_tasks: pip.yml
.
.
.
```

The roles I created reflect the second method, which is considered "best practice" by Ansible and if there's an intention to publish a role to [Ansible Galaxy](https://bit.ly/30eFH8B), then this writing method is a requirement.

Each sub-task is an "aim" which contains more than one task and each "aim" is described in a separate file.

For example, the common role directory contains the following files (aims):

![ansible role directory structure](../screenshots/common_dir_structure.png)

Each file contains a list of tasks related to the role.

**defaults directory**:

This is where you store the default values for a role's variables.

An example for a `main.yml` file for the consul-client role defaults:

```
---
# defaults file for consul-client
consul:
  version: "1.6.2"
  user: "root"
  group: "root"
  var_dir: "/var/consul"
  datacenter: "company"
  conf_dir: "/etc/consul.d/client"
  server_address: "consul.company.com"
  dns_server_address1: "192.168.1.88"
  dns_server_address2: "192.168.1.68"
  bin_path: "/usr/local/bin"
  slaves_prefix: "agent"
dns:
  company_domain: "{{ consul.datacenter }}.com"
  company_consul_domain: "node.{{ consul.datacenter }}.consul"
```

The above values can be accessed from within tasks like so:

`DOMAIN="{{ dns.company_domain }} {{ dns.company_consul_domain }}"`

This will yield:

`DOMAIN="company.com node.company.consul"`

An example task:

```
- name: Running dns.yml -- configure nic search domain
  lineinfile:
    path: /etc/sysconfig/network-scripts/ifcfg-{{ ansible_default_ipv4.interface }}
    line: 'DOMAIN="{{ dns.company_domain }} {{ dns.company_consul_domain }}"'
```

**meta directory**:

This directory contains the metadata about the role, like who wrote it what's his email address, any requirements, etc...

Example:

```
✗ cat ../meta/main.yml
galaxy_info:
  author: Itai Ganot
  description: A common role for CentOS/RedHat servers
  company: company
```

**files directory**:

If the tasks of the role you're writing require copying static files from the role to the machine's filesystem, this is where you're going to place the files.

For example, let's say you're working on a cron role which configures a script to run using cron, you will place the script file there and then copy it to its destination like so:

```
- name: copy script to its folder
    copy:
      src: "{{ role_path }}/files/cleanslave"
      dest: "{{ cron_scripts_path }}/cleanslave"
      owner: root
      group: root
      mode: '0700'
      remote_src: yes
```

**handlers directory**:

If you want a role's task to be able to restart a service when a new configuration is applied, you'll need to create a handler.

Let's say I configure postgres and I want to restart its service so it gets the new configuration, I will create such a handler in the `main.yml` file in the roles handlers directory:

```
- name: restart postgres9.4
  service: name=postgres9/4 state=restarted
  listen: "restart postgres9.4"
```

And then I can call the handler from a task:

```
- name: unarchive data file
  unarchive:
	src: /tmp/data.tar.gz
    dest: /var/lib/pgsql/{{ versions.postgres_c6 }}
    remote_src: yes
  notify:
  	- restart postgres9.4
```

You can create such a handler for each service operation that your role requires.


**templates directory**:

This is where you'll place configuration and other files that contain dynamic data.

Let's say that I'm working on a role which is supposed to configure DNS in a machine, I would want to configure the server's `resolv.conf` file.

So I'll place in the role's templates directory a file with the name of the actual file I want to configure with an extension of "j2" (Jinja2) and this file will contain the dynamic data I want to configure.

Example:

```
✗ cat resolv.conf.j2
search {{ config.search_domain }}
nameserver {{ config.nameserver1 }}
nameserver {{ config.nameserver2 }}
```

The above variables will be translated to the values contained in the `defaults/main.yml` file:

```
---
# defaults file for Jenkins-slave

config:
  nameserver1: "192.168.1.88"
  nameserver2: "192.168.1.68"
  search_domain: "{{ misc.datacenter }}.com node.{{ misc.datacenter }}.consul"
```


**With the above knowledge you'll be able to understand the current roles and develop new ones**

###### Written by Itai Ganot, lel@lel.bz
