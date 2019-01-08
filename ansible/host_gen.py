# /usr/bin/python

# generate hosts for ansible deployment on DataProc

from jinja2 import Template
import socket

# extract domain name of slaves
# original domain : my-dos-w-0.us-west1-b.c.seqslab-cloud.internal
# short domain : my-dos-w-0
# fatal: [my-dos-w-0.us-west1-b.c.seqslab-cloud.internal]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect
# to the host via ssh: Warning: Permanently added 'my-dos-w-0.us-west1-b.c.seqslab-cloud.internal' (ECDSA) to the list
# of known hosts.\r\nunix_listener: \"/home/chungtsai_su/.ansible/cp/ansible-ssh-my-dos-w-0.us-west1-b.c.seqslab-cloud.
# internal-22-chungtsai_su.CvLVq8eadZG6N2vz\" too long for Unix domain socket\r\n", "unreachable": true}

with open('/etc/hadoop/conf/nodes_include', 'r') as f:
    s = [line.strip().split(".")[0] for line in f]
# print(s)
template = Template("[master]\n{{ master }}\n\n[slave]\n{% for host in slaves -%}\n    {{ host}} \n{% endfor %}\n"
                    "[all:vars]\nansible_user=\nansible_ssh_pass=\nansible_become_pass=\n"
                    "ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ConnectionAttempts=20'\n")
with open('hosts', 'w') as f:
    f.write(template.render(master=socket.gethostname(), slaves=s))
