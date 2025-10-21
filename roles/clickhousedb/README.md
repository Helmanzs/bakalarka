# ClickHouseDB Role

[![Ansible](https://img.shields.io/badge/Ansible-2.16+-blue.svg)](https://docs.ansible.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Ubuntu%2024.04-orange.svg)](https://ubuntu.com/)
[![Galaxy](https://img.shields.io/badge/Galaxy-helmanz.clickhousedb-lightgrey.svg)](https://galaxy.ansible.com/helmanz/clickhousedb)

## Description

This Ansible role installs and configures **ClickHouseDB** inside **LXD-based virtual machines**.  
It is designed for **Ubuntu 24.04** LXD instances deployed using the **Simplestreams image server** and includes setup for benchmarking, data import, and query testing.

---

## Requirements

- **Ansible**: 2.16 or higher  
- **Target system**: LXD virtual machine (Ubuntu 24.04)  
- **System resources**: Minimum 4 GB RAM recommended  
- **Python 3.x** installed inside the container  
- **Sudo privileges** available on the target VM  

---

## Dependencies

This role depends on a base `common` role that prepares the LXD VM environment.
