# Database Benchmarking Playbooks

This repository contains Ansible playbooks to automate the setup, testing, and benchmarking of various databases (e.g., ClickHouse, PostgreSQL, MySQL) in containerized environments. Results are collected in a structured format for analysis.

## Folder Structure

```
playbook/
├── run_test.yml
├── results/
├── <db_name>/
│   └── tests/
│       ├── hot/
│       │   └── single-point.yml
│       └── cold/
│           └── single-point.yml
├── common/
│   └── vm_init_test.yml
└── ...
```

- **run_test.yml**: Main entry point to initialize results and run a test scenario for any supported database.
- **results/**: Directory where test results are stored.
- **<db_name>/tests/**: Test scenarios for each database, organized by cache state and test type.
- **common/**: Shared tasks and utilities.

## Prerequisites

- [Ansible](https://docs.ansible.com/) installed.
- [LXD](https://linuxcontainers.org/lxd/introduction/) or your container runtime installed and configured.
- Database images/containers available for your runtime.
- Host variables files (e.g., `/etc/ansible/host_vars/<db_name>.yml`) with necessary configuration for each DB.
- SSH access and required permissions.

## Usage

### 1. Prepare the Environment

- Ensure host variable files exist for each database you want to test.
- Make sure your container runtime and images are ready.

### 2. Run a Test

You can run a test scenario for any supported database by specifying variables:

```sh
ansible-playbook run_test.yml \
  -e "db=clickhousedb cache=hot test_type=single-point ram_profile=default cpu_profile=default"
```

**Variables you can override:**
- `db`: Database to test (e.g., `clickhousedb`, `postgresql`, `mysql`)
- `cache`: `hot` or `cold` (default: `hot`)
- `test_type`: e.g., `single-point` (default: `single-point`)
- `ram_profile`: RAM profile name (default: from your config)
- `cpu_profile`: CPU profile name (default: from your config)

### 3. Results

Results are saved in the `results/` directory as NDJSON files, named by test type and cache, e.g.:
```
results/single-point-hot_results.ndjson
results/single-point-cold_results.ndjson
```

Each line is a JSON object with metrics from a test run.

## Extending

- Add new databases by creating a folder structure like `<db_name>/tests/<cache>/<test_type>.yml`.
- Add or update resource profiles in your `resources_dir` or `common/`.
- Add new test types or cache scenarios as needed.

## Troubleshooting

- If you see recursion errors, ensure variables are not set in terms of themselves.
- Make sure all required variables are defined in your host/group vars or passed via `-e`.
- Check that your container runtime and images are accessible.

## License

MIT or your preferred license.

---

*For more details, see comments in each playbook file.*