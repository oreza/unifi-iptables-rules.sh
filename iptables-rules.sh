# Allowed Ports

# 
# https://help.ui.com/hc/en-us/articles/218506997-UniFi-Network-Required-Ports-Reference
# Unifi Stun UDP:3478
# Unifi Web TCP:8443

# Flush all the chains
iptables -F

ALLOWED_TCP="22 80 443 1023 6789 8080 8443"
ALLOWED_UDP="1900 3478 5514 10001"
ALLOWED_IPS=""1.1.1.1","1.1.1.1","1.1.1.1","1.1.1.1""


# Flush the filter table from INPUT or OUTPUT
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F


# Permit loopback interface traffic (because our host is not a router)
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT


# Drop invalid traffic (good idea since we use the connexion track module)
iptables -A INPUT -m state --state INVALID -j DROP
iptables -A OUTPUT -m state --state INVALID -j DROP

# Drop NULL Packets
iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP

# Drop XMAS packets
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# Allow icmp traffic (ping)
iptables -A INPUT -p icmp -j ACCEPT
iptables -A OUTPUT -p icmp -j ACCEPT

# Setup rules for unifi
for port in $ALLOWED_TCP
do
    iptables -A INPUT -p tcp -s $ALLOWED_IPS --dport $port -j ACCEPT
done

for port in $ALLOWED_UDP
do
    iptables -A INPUT -p udp -s $ALLOWED_IPS --dport $port -j ACCEPT
done


# https://ubuntuforums.org/showthread.php?t=1441483
# DNS
iptables -A INPUT -p tcp -m tcp --sport 53 -j ACCEPT
iptables -A INPUT -p udp -m udp --sport 53 -j ACCEPT

# ntpd
iptables -A OUTPUT -p udp --dport 123 -j ACCEPT
iptables -A INPUT -p udp --sport 123 -j ACCEPT

# apt-get
iptables -A INPUT -p tcp --sport 80 -j ACCEPT
iptables -A INPUT -p tcp --sport 443 -j ACCEPT

# rsyslog
iptables -A INPUT -m state --state NEW -m udp -p udp --dport 514 -j ACCEPT
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 514 -j ACCEPT


# Permit no more than 50 concurrent connections from the same ip address to our web server
iptables -A INPUT -p tcp -m multiport --dports 80,443,8080,8443 -m connlimit --connlimit-above 50 -j DROP

# Prevent brute force on port 22
iptables -A INPUT -p tcp -m tcp --dport 22 -m conntrack --ctstate NEW -m recent --set --name DEFAULT --mask "1.1.1.1" --rsource
iptables -A INPUT -p tcp -m tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 10 --name DEFAULT --mask "1.1.1.1" --rsource -j DROP

# Block Packets With Bogus TCP Flags
iptables -t mangle -A PREROUTING -p tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP
iptables -t mangle -A PREROUTING -p tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
iptables -t mangle -A PREROUTING -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
iptables -t mangle -A PREROUTING -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
iptables -t mangle -A PREROUTING -p tcp --tcp-flags FIN,ACK FIN -j DROP
iptables -t mangle -A PREROUTING -p tcp --tcp-flags ACK,URG URG -j DROP
iptables -t mangle -A PREROUTING -p tcp --tcp-flags ACK,FIN FIN -j DROP
iptables -t mangle -A PREROUTING -p tcp --tcp-flags ACK,PSH PSH -j DROP
iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL ALL -j DROP
iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL NONE -j DROP
iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP
iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL SYN,FIN,PSH,URG -j DROP
iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP


# Block Packets From Private Subnets (Spoofing)
_subnets=(""1.1.1.1"/3" ""1.1.1.1"/16" ""1.1.1.1"/12" ""1.1.1.1"/24"  ""1.1.1.1"/8" ""1.1.1.1"/8" ""1.1.1.1"/5")

for _sub in "${_subnets[@]}" ; do
  iptables -t mangle -A PREROUTING -s "$_sub" -j DROP
done
iptables -t mangle -A PREROUTING -s "1.1.1.1"/8 ! -i lo -j DROP

# Protection against port scanning
iptables -N port-scanning
iptables -A port-scanning -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s --limit-burst 2 -j RETURN
iptables -A port-scanning -j DROP

# Syn-flood protection
iptables -N syn_flood
iptables -A INPUT -p tcp --syn -j syn_flood
iptables -A syn_flood -m limit --limit 1/s --limit-burst 3 -j RETURN
iptables -A syn_flood -j DROP
iptables -A INPUT -p icmp -m limit --limit  1/s --limit-burst 1 -j ACCEPT
iptables -A INPUT -p icmp -m limit --limit 1/s --limit-burst 1 -j LOG --log-prefix PING-DROP:
iptables -A INPUT -p icmp -j DROP
iptables -A OUTPUT -p icmp -j ACCEPT

# Allow all outgoing valid traffic 
iptables -A OUTPUT -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# Drop anything in the blacklist ipset
iptables -I INPUT -m set --match-set blacklist src -j DROP
iptables -I FORWARD -m set --match-set blacklist src -j DROP

# Set the default policy to drop
iptables -P INPUT DROP
iptables -P OUTPUT DROP

# Save configuration changes
iptables-save > /etc/iptables/rules.v4
