#!/bin/bash

sudo systemctl enable arpwatch@eth1
sudo systemctl start arpwatch@eth1
sudo systemctl enable arpwatch@eth2
sudo systemctl start arpwatch@eth2
sudo systemctl enable arpwatch@eth3
sudo systemctl start arpwatch@eth3
sudo tail -f /var/log/syslog
