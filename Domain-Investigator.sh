#!/bin/bash
YEL=$'\e[1;33m' # Yellow
RED=$'\033[0;31m' # Red
NC=$'\033[0m' # No Color
PRPL=$'\033[1;35m' # Purple
GRN=$'\e[1;32m' # Green
BLUE=$'\e[3;49;34m' # Blue

#script logo with copyrights
printf "${BLUE}\n"
echo "██╗  ██╗██████╗ ██╗███╗   ██╗ ██████╗ "
echo "██║ ██╔╝██╔══██╗██║████╗  ██║██╔════╝"
echo "█████╔╝ ██████╔╝██║██╔██╗ ██║██║  ███╗"
echo "██╔═██╗ ██╔═══╝ ██║██║╚██╗██║██║   ██║"
echo "██║  ██╗██║     ██║██║ ╚████║╚██████╔╝"
echo "╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═══╝ ╚═════╝ "
printf "\nPowered by KeepSec Technologies Inc.™\n"
printf "${NC}\n"

#check if root or not
if [ `id -u` -ne 0 ]; then
      printf "${RED}\nThis script can only be executed as root\n\n${NC}"
      sleep 0.5
      exit
fi

#function for the installing wheel
function installing {
  tput civis
  spinner="⣾⣽⣻⢿⡿⣟⣯⣷"
  while :; do
    for i in $(seq 0 7); do
      printf "${PRPL}${spinner:$i:1}"
      printf "\010${NC}"
      sleep 0.2
    done
  done
}

#start wheel
installing &
SPIN_PID=$!
disown
printf "${PRPL}\nInstalling utilities ➜ ${NC}"

# Install whois and openssl if not installed
if command -v apt-get &> /dev/null; then
  sudo apt-get -y install whois openssl &> /dev/null
elif command -v yum &> /dev/null; then
  sudo yum -y install whois openssl &> /dev/null
elif command -v pacman &> /dev/null; then
  sudo pacman -S whois openssl &> /dev/null
else
  echo "Error: package manager not found" >&2
  exit 1
fi

#install postfix and mailx
if [ -n "`command -v postfix`" ]; then
  if [ -n "`command -v apt-get`" ];
  then sudo apt-get -y install bsd-mailx > /dev/null; 
  elif [ -n "`command -v yum`" ]; 
  then sudo yum install -y mailx > /dev/null; 
  else
  echo "Error: package manager not found" >&2
  exit 1
  fi
else
  read -p "What is the domain that will be used to send emails : " smtpdomain
  echo""
  if [ -n "`command -v apt-get`" ];
  then sudo apt-get -y install postfix > /dev/null  && sudo apt-get -y install bsd-mailx > /dev/null; 
    sudo echo "postfix postfix/mailname string $smtpdomain" | debconf-set-selections
    sudo echo "postfix postfix/protocols select  all" | debconf-set-selections
    sudo echo "postfix postfix/mynetworks string  127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128" | debconf-set-selections
    sudo echo "postfix postfix/mailbox_limit string  0" | debconf-set-selections
    sudo echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections
    sudo echo "postfix postfix/compat_conversion_warning   boolean true" | debconf-set-selections
    sudo echo "postfix postfix/protocols select all" | debconf-set-selections
    sudo echo "postfix postfix/procmail boolean false" | debconf-set-selections
    sudo echo "postfix postfix/relayhost string" | debconf-set-selections
    sudo echo "postfix postfix/chattr boolean false" | debconf-set-selections
    sudo echo "postfix postfix/destinations string $smtpdomain" | debconf-set-selections
  elif [ -n "`command -v yum`" ]; 
  then sudo yum install -y postfix > /dev/null  && sudo yum install -y mailx > /dev/null; 
    sudo sed -i -e "s/inet_interfaces = localhost/inet_interfaces = all/g" /etc/postfix/main.cf &> /dev/null
    sudo sed -i -e "s/#mydomain =.*/mydomain = $domain/g" /etc/postfix/main.cf &> /dev/null 
    sudo sed -i -e "s/#myorigin = $mydomain/myorigin = $mydomain/g" /etc/postfix/main.cf &> /dev/null
    sudo sed -i -e "s/#mynetworks =.*/mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128/g" /etc/postfix/main.cf &> /dev/null
    sudo sed -i -e "s/mydestination =.*/mydestination = mail."'$mydomain'", "'$mydomain'"/g" /etc/postfix/main.cf &> /dev/null
    sudo sed -i -e "117d" /etc/postfix/main.cf &> /dev/null
  else
  echo "Error: package manager not found" >&2
  exit 1
  fi
fi

#make notification user
sudo adduser --disabled-password --gecos "" notification &> /dev/null

#enable postfix mail services
sudo systemctl enable postfix &> /dev/null
sudo systemctl start postfix &> /dev/null
sudo systemctl reload postfix &> /dev/null

# Make directory for domains for cronjob
mkdir -p "$HOME/.domain-investigator" &> /dev/null
mkdir -p "/var/log/scripts" &> /dev/null

#kills spinning wheel
kill -9 $SPIN_PID &> /dev/null
tput cnorm
printf "\n\n"

# Prompt the user for a list of domain names, separated by space
read -p "Enter a list of domain names: " domains
read -p "Email to receive notifications of results: " to

# Put the domains in a file
echo "$domains" > "$HOME/.domain-investigator/domains.txt"
sed -i -e 's/ /\n/g' $HOME/.domain-investigator/domains.txt

#create secondary bash script for the cronjob and makes it executable
echo "#!/bin/bash
#date
whichdate=\$(date +%F)
# Convert the list of domain names into an array
declare -a domain_array
readarray -t domain_array < \"\$HOME/.domain-investigator/domains.txt\"

# Loop through the array of domain names
for domain in \"\${domain_array[@]}\"; do
  # Use the whois command to retrieve the expiration date of the domain
  domain_date=\$(echo | whois \"\$domain\" | grep 'Expiry Date:' | awk '{print \$4}' | cut -c1-10)
  # Connect to the domain over SSL and retrieve the expiration date of the certificate
  ssl_date=\$(echo | openssl s_client -connect \"\$domain\":443 2>/dev/null | openssl x509 -noout -dates | grep notAfter | awk -F'=' '{print \$2}' | awk '{print \$1,\$2,\$4}')
  # Print the domain name and its expiration date + SSL certificate expiration date and mail it
  printf \"\n\$domain expires on \$domain_date\n\$domain SSL certificate expires on \$ssl_date\n\n\" | mail -r \"notification\" -s \"\$domain Domain Investigator Results \$whichdate\" \"$to\"
done

exit" > "$HOME/.domain-investigator/dom-investig-cron.sh"
chmod +x $HOME/.domain-investigator/dom-investig-cron.sh &> /dev/null

#make a cron job that runs every month on the 1st at 00:00AM
croncmd="root /usr/bin/bash $HOME/.domain-investigator/dom-investig-cron.sh > /var/log/$dom-investig-cron.log"
cronjob="0 0 1 * * $croncmd"

printf "$cronjob\n" > /etc/cron.d/$0-cron

#run it
/usr/bin/bash $HOME/.domain-investigator/dom-investig-cron.sh 

#bye bye message :)
printf "\n\n${GRN}We're done!\n\n${NC}"

exit