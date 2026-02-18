# DevopsStuff

This repository contains practical DevOps examples, scripts, templates, and infrastructure code used in real projects and learning exercises.

The goal of this collection is to provide working, real-world DevOps artifacts that can be reused, adapted, or studied to improve automation, infrastructure management, and operational practices.

---

## Contents Overview

### Infrastructure as Code

- `terraform-projects/`  
  Examples of Terraform configurations for infrastructure automation.

- `terraform/company_project/`  
  A structured Terraform deployment for a company project with reusable modules and environments.

---

### Automation Scripts

- `Scripts/`  
  Contains automation scripts for cloud and system tasks. For example:
  - AWS utilities (e.g., investigate security groups and IAM)

---

### Configuration Management

- `ansible/`  
  Ansible playbooks and roles for server configuration and automation.

---

### Kubernetes Examples

- `k8s/`  
  Kubernetes manifests and deployment examples.

---

### Development Environments

- `local_development_environment/`  
  Setup and support scripts for local development workflows.

---

### Other Examples

- `devops_course/`  
  Exercises and code from DevOps training modules.
- `e-commerce-app/`  
  Application used for deployment and integration examples.
- `nightly_scale_down_project/`  
  Example of automation designed to scale down resources on a schedule.
- `puppet_modules/`, `redis_compose/`  
  Examples of other automation and orchestration tooling usage.
- `jq_examples.md`  
  Examples of using `jq` for JSON manipulation in automation scripts.

---

## Usage

Each folder contains its own README or inline documentation describing how to run the code, configure the tools, or apply the infrastructure.

General patterns in this repository include:

1. **Infrastructure provisioning** using Terraform.
2. **Configuration automation** using Ansible.
3. **Scripting** with Python, Shell, and utility tools for DevOps tasks.
4. **Kubernetes workloads** for deployment and cluster automation.

---

## Getting Started

To explore this repository:

1. Clone the repo:

   ```bash
   git clone https://github.com/geek-kb/DevopsStuff.git
   cd DevopsStuff
   ```

2. Review folder structure and navigate to examples of interest.

3. Read individual folder-level documentation for usage details.

---

## Contributing

Contributions of useful scripts, templates, and examples are welcome. When contributing:

- Follow consistent naming and structure.
- Include descriptive README sections for any new folder.
- Ensure code and scripts work as expected in a typical DevOps environment.

---

## About

This collection is intended as a reference and reusable resource for DevOps engineers seeking practical examples across common operational and automation tasks. It is not tied to a single commercial product or vendor.
