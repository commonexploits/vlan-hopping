# Frogger - VLAN Hopping

This tool allows the capture and analysis of CDP, DTP and VTP packets, with the objective of extracting information from the network and automating the enumeration and exploitation of deficiencies that allow hopping between VLANs.

## Install

```commandline
git clone https://github.com/xtormin/frogger-vlan-hopping.git
```

## Usage
    
```
sudo bash frogger.sh
```

# Features

* Sniffs out CDP packets and extracts (VTP domain name, VLAN management address, Native VLAN ID and IOS version of Cisco devices)
* It will enable a DTP trunk attack automatically
* Sniffs out and extracts all 802.1Q tagged VLAN packets within STP packets and extracts the unique IDs.
* Auto arp-scans the discovered VLAN IDs and auto tags packets and scans each VLAN ID for live devices.
* Auto option to auto create a VLAN interface within the found network to connect to that VLAN.
* Added SNMP VLAN informaion extraction
* Added SNMP VLAN Hopping
* Added DTP Scan - Passively detect DTP modes and VLAN hopping possibility
* Added CDP info extraction

# Requirements   

* Arp-Scan 1.8 (in order to support VLAN tags must be V1.8 - Backtrack ships with V1.6 that does not support VLAN tags) http://www.nta-monitor.com/tools-resources/security-tools/arp-scan
* Yersina (built into Backtrack)
* Tshark (buit into Backtrack)
* Screen (built into Backtrack)
* Vconfig (built into Backtrack)


Tested on Kali2. All dependencies will be checked for when running.

* Notes for VMware. VLAN hopping generally (not just this script) can have issues within VMware if running the VM within Windows with certain Intel drivers. The Intel drivers strip off the tags before it reaches the VM. Either use an external USB ethernet card such as a DLink USB 2.0 DUB-E100 (old model 10/100 not gigabit) or boot into Backtrack nativiely from a USB stick. Intel has published a registry fix, to work on some models: http://www.intel.com/support/network/sb/CS-005897.htm - adding "MonitorMode" 1 to the registry does resolve the issue.

# Change Log

* Version 2.0 - 14/09/16 - 44CON Release. Info/Help to publish soon. Added DTPScan, SNMP Hopping. Many improvements.
* Version 1.8 - Added VMware detection and Intel NIC detection to assist with common problems within VMware.
* Version 1.7 - New look, bug fixes and speed improvements.
* Version 1.5 - Official release.

# Original Developer

Developed by Daniel Compton

https://github.com/commonexploits/vlan-hopping

Released under AGPL see LICENSE for more information
