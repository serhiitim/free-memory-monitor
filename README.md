copy memmonit.service (timer) > /etc/systemd/system/
copy memmonit.sh > /usr/bin/ ; chmod +x /usr/bin/memmonit.sh

# Start timer
systemctl start memmonit.timer
# Check timer status
systemctl list-timers

# Read log
tail -f /var/log/flussonic_ram_monitor.log
