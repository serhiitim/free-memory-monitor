# Copy service and timer file to work directory
cp memmonit.service /etc/systemd/system/
cp memmonit.timer /etc/systemd/system/

# Copy script to work directory and make him executible
cp memmonit.sh /usr/bin/ 
chmod +x /usr/bin/memmonit.sh

#systemctl daemon-reload
#systemctl enable memmonit
#service memmonit status

# Start timer
systemctl start memmonit.timer
# Check timer status
systemctl list-timers

# Read log
tail -f /var/log/flussonic_ram_monitor.log
