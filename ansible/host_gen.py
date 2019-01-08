# /usr/bin/python

# generate hosts for ansible deployment on DataProc

from jinja2 import Template
import socket


with open('/etc/hadoop/conf/nodes_include', 'r') as f:
    s = [line.strip() for line in f]
# print(s)
template = Template("[master]\n{{ master }}\n\n[slave]\n{% for host in slaves -%}\n    {{ host}} \n{% endfor %}\n"
                    "[all:vars]\nansible_user=\nansible_ssh_pass=\nansible_become_pass=\n"
                    "ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ConnectionAttempts=20'\n")
with open('hosts', 'w') as f:
    f.write(template.render(master=socket.gethostname(), slaves=s))
