#!/bin/bash
# Script to start Kismet wireless sniffer

# Set CTRL-C (break) to bring down wlan1mon interface that Kismet creates
trap f_endclean INT
trap f_endclean KILL

# Put kismet_ui.conf into position if first run
f_uicheck(){
  if [ ! -f /root/.kismet/kismet_ui.conf ]; then
    mkdir /root/.kismet
    cp /etc/kismet/kismet_ui.conf /root/.kismet/
  fi
}

# Check for BlueNMEA then start gpsd to log GPS data
f_gps_check(){

  ps ax |grep bluenmea |grep -v grep &> /dev/null
  GPS_STATUS=$?

  if [ $GPS_STATUS -eq 0 ]; then
    gpsd -n -D5 tcp://localhost:4352
  fi
}

f_endclean(){
  ifconfig wlan1mon down &> /dev/null
  ifconfig wlan1 down &> /dev/null
  iw dev wlan1mon del &> /dev/null

  if [ $GPS_STATUS -eq 0 ]; then
    killall -9 gpsd
  fi
}

f_pulse_suspend(){
  if [ -e /etc/init.d/pwnix_kismet_server ]; then
    service pwnix_kismet_server status &> /dev/null
    if [ $? = 0 ]; then
      printf "Stopping Pwn Pulse kismet service...\n"
      service pwnix_kismet_server stop
      service pwnix_kismet_server status &> /dev/null
      if [ $? = 0 ]; then
        printf "Failed to stop kismet, please stop it manually.\n"
        exit 1
      else
        RESTART_KISMET=1
      fi
    fi
  fi
  if [ -z "${RESTART_KISMET}" ]; then
    find_kismet
    check_port
  fi
}

f_pulse_restore(){
  if [ "${RESTART_KISMET}" = 1 ]; then
    printf "Restarting Pwn Pulse kismet service...\n"
    service pwnix_kismet_server start
    sleep 2
    service pwnix_kismet_server status
    if [ $? = 0 ]; then
      printf "Successfully restarted Pwn Pulse kismet service.\n"
    else
      printf "Failed to restart Pwn Pulse kismet service.\n"
    fi
  fi
}

find_kismet() {
  found_kismet=$(pgrep -x kismet_server)
  if [ -n "$found_kismet" ]; then
    printf "Kismet is already running on PID $found_kismet.\n"
    exit 1
  fi
}

check_port(){
  port_2501=$(lsof -Pni 4TCP:2501 | grep :2501 | awk '{print $2}')
  if [ -n "$port_2501" ]; then
    printf "Something already bound to port 2501 with PID $port_2501\n"
    exit 1
  fi
}

clear
echo
echo  "Kismet captures saved to /opt/pwnix/captures/wireless/"
echo

wait 3

cd /opt/pwnix/captures/wireless/

f_pulse_suspend
f_uicheck
f_gps_check
kismet
f_endclean
f_pulse_restore

