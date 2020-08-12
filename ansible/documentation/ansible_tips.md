# Ansible tips

### registers

Registers allow me to run a command using Ansible and capture its output into a variable.

Example:

```
- name: check if /etc/sysconfig/network contains word "anaconda"
  shell: grep "anaconda" /etc/sysconfig/network
  register: grep_result
  ignore_errors: yes
```

You can see how in the above example, I ran `grep "anaconda" /etc/sysconfig/network` and saved the output to a variable called "hostname_result".

The `ignore_errors` directive tells Ansible that even if an error occurs, for example, because no line contains the word "anaconda" in the file, it won't fail the playbook run, because, by default, every failing task will fail the whole playbook run.

so now, the play process contains a variable which has the output of the `grep` command and when I run the playbook, the register gets populated with the result of the grep command, it looks like so:

```
PLAY [localhost] *****************************************************************************************************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************************************************************
Monday 10 August 2020  13:49:27 +0300 (0:00:00.023)       0:00:00.023 *********
ok: [localhost]

TASK [test_role : check if anaconda in /etc/sysconfig/network] *****************************************************************************************************************************************************************
Monday 10 August 2020  13:49:29 +0300 (0:00:02.255)       0:00:02.278 *********
changed: [localhost]

TASK [test_role : debug] *********************************************************************************************************************************************************************************************************************
Monday 10 August 2020  13:49:30 +0300 (0:00:00.560)       0:00:02.839 *********
ok: [localhost] => {
    "msg": {
        "changed": true,
        "cmd": "grep \"anaconda\" /etc/sysconfig/network",
        "delta": "0:00:00.069291",
        "end": "2020-08-10 13:49:29.966570",
        "failed": false,
        "rc": 0,
        "start": "2020-08-10 13:49:29.897279",
        "stderr": "",
        "stderr_lines": [],
        "stdout": "# Created by anaconda",
        "stdout_lines": [
            "# Created by anaconda"
        ]
    }
}

PLAY RECAP ***********************************************************************************************************************************************************************************************************************************
localhost                  : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

I can now access each metadata using the register, like so:

```
grep_result.rc will yield "0"
grep_result.stdout will yield "# Created by anaconda"
etc...
```

so in a playbook, I will use it like so:

```
---

- name: check if /etc/sysconfig/network contains word "anaconda"
  shell: grep "anaconda" /etc/sysconfig/network
  register: grep_result
  ignore_errors: yes

- name: touch a test file
  file:
  	path: /etc/foo.conf
  	state: touch
  	mode: u=rw,g=r,o=r

- name: verify line in file
  lineinfile:
  	path: /etc/foo.conf
  	line: "{{ grep_result.stdout }}"
```

### debug

Sometimes, when developing roles and using registers, we are not entirely sure what each register returns so we would want to print its output to find out what are our options, to do that, you create a debug task which prints your register.

For example, let's take the playbook I created for the previous example:

```
---
# tasks file for test_role

- name: check if word is in /etc/sysconfig/network
  shell: grep "anaconda" /etc/sysconfig/network
  register: grep_result
  ignore_errors: yes

- debug: msg="{{ grep_result }}"
```

You can see how I tell Ansible what I want it to print in the "debug" task - show me everything the register contains.


### facts

Facts are variables which are discovered from systems.
There are other places where variables can come from, but these are a type of variable that is discovered, not set by the user.

To get a list of facts, you run the following command:

`ansible localhost -m setup`

Running the above command will return a very long list of facts that Ansible knows about that system like which processor is installed in the machine, how many network interface cards are present in the machine and information about each one of them, the hostname of the machine, and any piece of information you might need.

To enable Ansible to gather these facts, we need to add it to the relevant playbook, in company's playbooks, it's already added by me in all the playbooks (gather_facts: true).

Example:

```
---

- hosts: localhost
  #vars:
    #ansible_python_interpreter: /usr/bin/python2
  gather_facts: true
  roles:
    - hosts
    - consul-client
    - node-exporter

```

This is an example task where I use it:

```
- name: verify bind ip is correct
  replace:
    path: /etc/systemd/system/consul-client.service
    regexp: '^ExecStart.*'
    replace: "ExecStart=/bin/bash -c \"/usr/bin/consul agent -bind {{ ansible_default_ipv4.address }} -config-dir /etc/consul.d/client\""
  when: wrong_ip_set.stdout != ansible_default_ipv4.address
```

In the above example, I configure consul-client's systemd service file... I'm replacing a line which starts with "^ExecStart.\*" not caring how it continues and I replace it with a line that looks like so:

```
"ExecStart=/bin/bash -c \"/usr/bin/consul agent -bind {{ ansible_default_ipv4.address }} -config-dir /etc/consul.d/client\""
```

So in the above example, "{{ ansible\_default\_ipv4.address }}" - translates to the machine's default network interface card ipv4 address.

The use of such facts makes roles development a fairly easy task.


### conditions

In many cases, you want a task run only when certain condition applies.

For example:

```
- name: python installation on centos 6 machines
  block:
  - import_tasks: python2_centos6.yml
  - import_tasks: python3_centos6.yml
  when: ansible_distribution_major_version == "6"
```

In the above example, I want python2_centos6.yml and python3_centos6.yml playbooks to run only on machines that their distribution major version is 6 (centos6 for example).

So when this role runs on a Centos 7 machine, this block will get ignored because the major version of the OS is 7 and not 6.

But when this role runs on Centos 6 machines, it will be applied and the tasks will be imported.

"when" conditions can also contain comparisons such as equals, not equals, etc...

Example:

```
- name: configure client as ci
  template: src=ci_config_with_meta.json.j2 dest="{{ consul.conf_dir }}/config.json"
  when: check_slave_result.rc != 0
```

###### Written by Itai Ganot, lel@lel.bz
