# iptable rules customized for Unifi network controller
iptables rules customized to be deployed on Unifi Controller hosted on RaspberryPi 4 

## Notes: 
- Ubuntu 20.04 came enabled with `netfilter-persistence.service`, and ufw and iptables disabled. 
- Block `admin.unifi-ai.com` ("1.1.1.1"), even though we have installed Unifi Controller Locally and instructed it to not sync with Unifi Cloud, it still dials homes.
- Using `iptables-persistent` package (which automatically pulls in `netfilter-persistent` package, this will automatically disable `iptables.service` and ufw, if you want ufw, that make changes to SystemD integration appropriately. 
- The file `sanatize.list` is used to sanatize common content based filtering using `git-filter-repo`

## Prerequisites
For Ubuntu 20.04 
`sudo apt-get install ipset`
`sudo apt install iptables-persistent`

## SystemD integration
### Unit file for ipset presistence
```
Description=ipset Persistancy Service
DefaultDependencies=no
Requires=netfilter-persistent.service
Before=network.target
Before=netfilter-persistent.service
ConditionFileNotEmpty=/etc/ipsets.conf
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/ipset restore -f -! /etc/ipsets.conf
# save on service stop, system shutdown etc.
ExecStop=/sbin/ipset save blacklist -f /etc/ipsets.conf
[Install]
WantedBy=multi-user.target
RequiredBy=netfilter-persistent.service
```
