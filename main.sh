#!/bin/bash
unalias -a # Get rid of aliases
echo "unalias -a" >> ~/.bashrc
echo "unalias -a" >> /root/.bashrc
PWDthi=$(pwd)
if [ ! -d $PWDthi/referenceFiles ]; then
    echo "Please Cd into this script's directory"
    exit
fi
if [ "$EUID" -ne 0 ]; then
    echo "Run as Root"
    exit
fi

startFun() {
    clear

    zeroUidFun
    rootCronFun
    apacheSecFun
    fileSecFun
    netSecFun
    aptUpFun
    aptInstFun
    deleteFileFun
    firewallFun
    sysCtlFun
    scanFun
    repoFun
    
    printf "\033[1;31mDone!\033[0m\n"
}

cont() {
    printf "\033[1;31mI have finished this task. Continue to next Task? (Y/N)\033[0m\n"
    read contyn
    if [ "$contyn" = "N" ] || [ "$contyn" = "n" ]; then
        printf "\033[1;31mAborted\033[0m\n"
        exit
    fi
    clear
}

zeroUidFun() {
    printf "\033[1;31mChecking for 0 UID users...\033[0m\n"
    touch /zerouidusers
    touch /uidusers

    cut -d: -f1,3 /etc/passwd | egrep ':0$' | cut -d: -f1 | grep -v root > /zerouidusers

    if [ -s /zerouidusers ]; then
        echo "There are Zero UID Users! I'm fixing it now!"
        while IFS='' read -r line || [[ -n "$line" ]]; do
            thing=1
            while true; do
                rand=$(( ( RANDOM % 999 ) + 1000))
                cut -d: -f1,3 /etc/passwd | egrep ":$rand$" | cut -d: -f1 > /uidusers
                if [ -s /uidusers ]; then
                    echo "Couldn't find unused UID. Trying Again... "
                else
                    break
                fi
            done
            usermod -u $rand -g $rand -o $line
            touch /tmp/oldstring
            old=$(grep "$line" /etc/passwd)
            echo $old > /tmp/oldstring
            sed -i "s~0:0~$rand:$rand~" /tmp/oldstring
            new=$(cat /tmp/oldstring)
            sed -i "s~$old~$new~" /etc/passwd
            echo "ZeroUID User: $line"
            echo "Assigned UID: $rand"
        done < "/zerouidusers"
        update-passwd
        cut -d: -f1,3 /etc/passwd | egrep ':0$' | cut -d: -f1 | grep -v root > /zerouidusers

        if [ -s /zerouidusers ]; then
            echo "WARNING: UID CHANGE UNSUCCESSFUL!"
        else
            echo "Successfully Changed Zero UIDs!"
        fi
    else
        echo "No Zero UID Users"
    fi
    cont
}

rootCronFun() {
    printf "\033[1;31mChanging cron to only allow root access...\033[0m\n"
    crontab -r
    cd /etc/
    /bin/rm -f cron.deny at.deny
    echo root > cron.allow
    echo root > at.allow
    /bin/chown root:root cron.allow at.allow
    /bin/chmod 644 cron.allow at.allow
    cont
}

apacheSecFun() {
    printf "\033[1;31mSecuring Apache...\033[0m\n"
    a2enmod userdir

    chown -R root:root /etc/apache2
    chown -R root:root /etc/apache

    if [ -e /etc/apache2/apache2.conf ]; then
        echo "<Directory />" >> /etc/apache2/apache2.conf
        echo "        AllowOverride None" >> /etc/apache2/apache2.conf
        echo "        Order Deny,Allow" >> /etc/apache2/apache2.conf
        echo "        Deny from all" >> /etc/apache2/apache2.conf
        echo "</Directory>" >> /etc/apache2/apache2.conf
        echo "UserDir disabled root" >> /etc/apache2/apache2.conf
    fi

    systemctl restart apache2.service
    cont
}

fileSecFun() {
    printf "\033[1;31mSome automatic file inspection...\033[0m\n"
    cut -d: -f1,3 /etc/passwd | egrep ':[0-9]{4}$' | cut -d: -f1 > /tmp/listofusers
    echo root >> /tmp/listofusers
    
    cat $PWDthi/referenceFiles/sources.list > /etc/apt/sources.list
    apt-get update
    cat $PWDthi/referenceFiles/lightdm.conf > /etc/lightdm/lightdm.conf
    cat $PWDthi/referenceFiles/sshd_config > /etc/ssh/sshd_config
    /usr/sbin/sshd -t
    systemctl restart sshd.service
    echo 'exit 0' > /etc/rc.local

    nano /etc/resolv.conf
    nano /etc/hosts
    visudo
    nano /tmp/listofusers
    cont
}

netSecFun() {
    printf "\033[1;31mSome manual network inspection...\033[0m\n"
    lsof -i -n -P
    netstat -tulpn
    cont
}

aptUpFun() {
    printf "\033[1;31mUpdating computer...\033[0m\n"
    apt-get update
    apt-get dist-upgrade -y
    apt-get install -f -y
    apt-get autoremove -y
    apt-get autoclean -y
    apt-get check
    cont
}

aptInstFun() {
    printf "\033[1;31mInstalling programs...\033[0m\n"
    apt-get install -y chkrootkit clamav rkhunter apparmor apparmor-profiles
    wget https://cisofy.com/files/lynis-2.5.5.tar.gz -O /lynis.tar.gz
    tar -xzf /lynis.tar.gz --directory /usr/share/
    cont
}

deleteFileFun() {
    printf "\033[1;31mDeleting dangerous files...\033[0m\n"
    find / -name '*.mp3' -type f -delete
    find / -name '*.mov' -type f -delete
    find / -name '*.mp4' -type f -delete
    find / -name '*.avi' -type f -delete
    find / -name '*.mpg' -type f -delete
    find / -name '*.mpeg' -type f -delete
    find / -name '*.flac' -type f -delete
    find / -name '*.m4a' -type f -delete
    find / -name '*.flv' -type f -delete
    find / -name '*.ogg' -type f -delete
    find /home -name '*.gif' -type f -delete
    find /home -name '*.png' -type f -delete
    find /home -name '*.jpg' -type f -delete
    find /home -name '*.jpeg' -type f -delete
    cd / && ls -laR 2> /dev/null | grep rwxrwxrwx | grep -v "lrwx" &> /tmp/777s
    cont
}

firewallFun() {
    printf "\033[1;31mSetting up firewall...\033[0m\n"
    apt-get remove -y ufw
    apt-get install -y iptables
    apt-get install -y iptables-persistent
    mkdir /iptables/
    touch /iptables/rules.v4.bak
    touch /iptables/rules.v6.bak
    iptables-save > /iptables/rules.v4.bak
    ip6tables-save > /iptables/rules.v6.bak
    iptables -t nat -F
    iptables -t mangle -F
    iptables -t nat -X
    iptables -t mangle -X
    iptables -F
    iptables -X
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
    iptables-save > /etc/iptables/rules.v4
    ip6tables-save > /etc/iptables/rules.v6
    systemctl enable iptables
    systemctl start iptables
    systemctl enable ip6tables
    systemctl start ip6tables
    cont
}

sysCtlFun() {
    printf "\033[1;31mUpdating Sysctl configurations...\033[0m\n"
    cp /etc/sysctl.conf /etc/sysctl.conf.bak
    sysctl -p
    sysctl -w net.ipv4.tcp_syncookies=1
    sysctl -w net.ipv4.conf.all.accept_source_route=0
    sysctl -w net.ipv4.conf.default.accept_source_route=0
    sysctl -w net.ipv4.conf.all.rp_filter=1
    sysctl -w net.ipv4.conf.default.rp_filter=1
    sysctl -w net.ipv4.tcp_rmem='4096 87380 4194304'
    sysctl -w net.ipv4.tcp_wmem='4096 87380 4194304'
    sysctl -w net.ipv4.ip_forward=0
    sysctl -w net.ipv4.icmp_echo_ignore_all=1
    sysctl -w net.ipv4.tcp_timestamps=0
    sysctl -w net.ipv4.tcp_fin_timeout=15
    sysctl -w net.ipv4.tcp_keepalive_time=120
    sysctl -w net.ipv4.tcp_retries2=5
    sysctl -w net.core.rmem_max=16777216
    sysctl -w net.core.wmem_max=16777216
    sysctl -w net.core.netdev_max_backlog=2500
    sysctl -w net.core.somaxconn=4096
    sysctl -w kernel.msgmni=28816
    sysctl -w kernel.sem='250 32000 32 128'
    sysctl -w fs.file-max=2097152
    sysctl -w fs.inotify.max_user_watches=524288
    cont
}

scanFun() {
    printf "\033[1;31mScanning the system..\033[0m\n"
    lynis audit system
    cont
}

repoFun() {
    printf "\033[1;31mConfiguring repositories..\033[0m\n"
    sed -i 's/http:\/\/archive.ubuntu.com/http:\/\/mirror.cse.iitk.ac.in/g' /etc/apt/sources.list
    sed -i 's/http:\/\/security.ubuntu.com/http:\/\/mirror.cse.iitk.ac.in/g' /etc/apt/sources.list
    cont
}

startFun
