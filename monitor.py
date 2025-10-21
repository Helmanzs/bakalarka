#!/usr/bin/env python3

import psutil
import time
from datetime import datetime

LOG_FILE = "system_monitor.log"
INTERVAL = 5

def log_system_usage():
    with open(LOG_FILE, "a") as log:
        while True:
            now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

            cpu = psutil.cpu_percent(interval=1)
            ram = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            net = psutil.net_io_counters()

            log_line = (
                f"[{now}] CPU: {cpu:.1f}% | "
                f"RAM: {ram.percent:.1f}% ({ram.used // (1024 * 1024)}MB used of {ram.total // (1024 * 1024)}MB) | "
                f"Disk: {disk.percent:.1f}% used | "
                f"Net: Sent={net.bytes_sent // (1024 * 1024)}MB, Received={net.bytes_recv // (1024 * 1024)}MB\n"
            )

            log.write(log_line)
            log.flush()

            time.sleep(INTERVAL)

if __name__ == "__main__":
    log_system_usage()
