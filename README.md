# Homelab Infrastructure Setup Guide

This repository contains the necessary configuration files and instructions to set up a complete homelab infrastructure using Nomad, Consul, and Vault, with Caddy as a reverse proxy and Cloudflare for secure external access.

## Architecture Overview

The infrastructure consists of the following components:

- **Nomad**: For orchestrating and scheduling containerized workloads
- **Consul**: For service discovery, configuration, and health checking
- **Vault**: For secrets management
- **Caddy**: As a reverse proxy with automatic HTTPS
- **Cloudflared**: For secure tunneling to external domains

The setup includes both server nodes (running Nomad, Consul, and Vault) and edge nodes (running Caddy and Cloudflared).

```
                                  ┌─────────────┐
                                  │  Internet   │
                                  └──────┬──────┘
                                         │
                                         ▼
                          ┌─────────────────────────────┐
                          │     Cloudflare Tunnel       │
                          └──────────────┬──────────────┘
                                         │
                                         ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                                Edge Node                                 │
│                                                                         │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────────┐  │
│  │ Cloudflared │───▶│    Caddy    │◀───│    Consul-Template          │  │
│  └─────────────┘    └──────┬──────┘    └─────────────────────────────┘  │
└────────────────────────────┼──────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                            Nomad Cluster                                 │
│                                                                         │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                  │
│  │    Nomad    │───▶│   Consul    │◀───│    Vault    │                  │
│  └─────────────┘    └─────────────┘    └─────────────┘                  │
│         ▲                  ▲                  ▲                         │
│         │                  │                  │                         │
│         ▼                  ▼                  ▼                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     Docker + Applications                        │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### Network Setup

The infrastructure uses a VLAN-based network to segment homelab traffic. Here's a simplified diagram:

```
                  ┌───────────────────┐
                  │   Router/Firewall │
                  └─────────┬─────────┘
                            │
                            ▼
┌───────────────────────────────────────────────────────────┐
│                     Managed Switch                         │
└───────┬───────────────┬─────────────────┬─────────────────┘
        │               │                 │
        ▼               ▼                 ▼
   ┌─────────┐     ┌─────────┐       ┌─────────┐
   │  VLAN 10 │     │  VLAN 20 │       │  VLAN 30 │
   │ (Homelab)│     │   (IoT)  │       │  (Guest) │
   └─────────┘     └─────────┘       └─────────┘
```

All homelab services run on VLAN 10 (ID used in configuration), but this can be customized based on your network setup.

## Hardware Requirements

### Minimum Requirements (for testing)
- 1 server node: 4 CPU cores, 8GB RAM, 100GB storage
- 1 edge node: 2 CPU cores, 4GB RAM, 20GB storage
- Network with VLAN support (not strictly required, but recommended)

### Recommended Setup
- 3 server nodes: 8+ CPU cores, 32GB+ RAM, 500GB+ storage each
- 2 edge nodes: 4 CPU cores, 8GB RAM, 50GB storage each
- Gigabit network with managed switch supporting VLANs

## Prerequisites

Before beginning the installation, ensure you have:

1. **Base OS Installation**:
   - Ubuntu 22.04 LTS or Debian 12 installed on all nodes
   - SSH enabled and accessible

2. **Network Configuration**:
   - Static IP addresses assigned to all nodes
   - VLAN configured on your network switch (VLAN ID 10 used in this setup)
   - DNS server (internal or external) for resolving `.homelab.local` domains

3. **External Services**:
   - Cloudflare account with a registered domain
   - Cloudflare API token with Zone:Read and Zone:Edit permissions

4. **SSH Keys**:
   - Generate SSH keys for the admin user: `ssh-keygen -t ed25519`
   - Ensure the public key is available at `~/.ssh/id_ed25519.pub`

5. **Ansible**:
   - Ansible 2.12+ installed on your control machine
   - Python 3.9+ installed

## Installation Steps

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/homelab-infra.git
cd homelab-infra
```

### 2. Configure the Hosts File

Edit the `package/hosts.yml` file to match your network configuration:

```yaml
# Example configuration
all:
  children:
    edge_nodes:
      hosts:
        edge01:
          network_address: "10.0.1.5"  # Replace with your IP
          ansible_host: "10.0.1.5"     # Replace with your IP
          # ... other settings
    nomad_cluster:
      hosts:
        server01:
          network_address: "10.0.1.10"  # Replace with your IP
          ansible_host: "10.0.1.10"     # Replace with your IP
          # ... other settings
        # ... other servers
```

### 3. Configure Group Variables

Edit the following files to match your environment:

- `package/bootstrap/group_vars/all.yml`: Common settings
- `package/bootstrap/group_vars/nomad_cluster.yml`: Nomad-specific settings
- `package/bootstrap/group_vars/edge_nodes.yml`: Edge node settings

Key settings to update:

- `ansible_password`: Your SSH password hash (generate with `mkpasswd --method=sha-512`)
- `ssh_public_key`: Path to your SSH public key
- `network_gateway`: Your network gateway
- `network_netmask`: Your network mask
- `vlan_id`: Your VLAN ID
- `consul_raw_key`: Generate with `consul keygen`
- Cloudflare settings in `edge_nodes.yml`

> **IMPORTANT SECURITY NOTE**: Replace ALL placeholder passwords, tokens, and secrets before deploying. Never use the default values in production environments.

### 4. Generate Required Secrets

#### Consul Encryption Key
```bash
consul keygen
```

#### Vault AWS KMS Key (if using AWS KMS for auto-unseal)
Create an AWS KMS key and note the key ID.

#### Cloudflare Tunnel
1. Create a tunnel in the Cloudflare Zero Trust dashboard
2. Note the tunnel ID and secret
3. Update the `cf_tunnels` section in `edge_nodes.yml`

### 5. Install Ansible Requirements

```bash
cd package/bootstrap
ansible-galaxy install -r requirements.yml
```

### 6. Run the Ansible Playbook

```bash
ansible-playbook -i ../hosts.yml site.yml
```

You can also run specific parts of the playbook using tags:

```bash
# Just bootstrap the nodes
ansible-playbook -i ../hosts.yml site.yml --tags bootstrap

# Just set up Nomad
ansible-playbook -i ../hosts.yml site.yml --tags nomad
```

### 7. Access the Services

After installation, you can access the following services:

- **Nomad UI**: https://nomad.homelab.local
- **Consul UI**: https://consul.homelab.local
- **Vault UI**: https://vault.homelab.local

### 8. Initialize Vault

After installation, you need to initialize Vault:

```bash
# SSH into a server node
ssh admin@server01

# Initialize Vault
vault operator init

# This will output 5 unseal keys and a root token
# SAVE THESE SECURELY!

# Unseal Vault (needs to be done on each Vault server)
vault operator unseal <unseal-key-1>
vault operator unseal <unseal-key-2>
vault operator unseal <unseal-key-3>
```

### 9. Configure Vault for Nomad

```bash
# Log in to Vault
vault login <root-token>

# Enable the Nomad secrets engine
vault secrets enable nomad

# Configure Nomad secrets engine
vault write nomad/config/access \
    address=http://localhost:4646 \
    token=<nomad-management-token>

# Create a Nomad role for workloads
vault write nomad/role/nomad-workloads \
    policies=nomad-workload-policy \
    type=client \
    ttl=1h
```

## Storage Configuration (Optional)

If you need persistent storage for your applications, you have several options:

1. **Local Storage**: Use local paths on the nodes (simplest approach)
2. **Docker Volumes**: Utilize Docker volume management
3. **External Storage**: Mount external storage systems like NFS (requires additional setup)

If you choose to use external storage, you'll need to:
1. Configure the storage service 
2. Mount the storage on your nodes
3. Update volume paths in your job specifications

## Deploying Services

To deploy services to your cluster, create Nomad job files and submit them:

```bash
# Example job deployment
nomad job run your-service.nomad
```

### Example Job: Simple Web Service

Here's a simple example to deploy Nginx:

```hcl
job "nginx" {
  datacenters = ["homelab"]
  type = "service"

  group "web" {
    count = 1
    
    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "nginx"
      port = "http"
      tags = ["caddy", "public"]
      
      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "nginx" {
      driver = "docker"
      
      config {
        image = "nginx:latest"
        ports = ["http"]
        volumes = [
          "local/default.conf:/etc/nginx/conf.d/default.conf",
          "local/index.html:/usr/share/nginx/html/index.html"
        ]
      }
      
      template {
        destination = "local/default.conf"
        data = <<EOH
server {
    listen 80;
    server_name localhost;
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
EOH
      }
      
      template {
        destination = "local/index.html"
        data = <<EOH
<!DOCTYPE html>
<html>
<head>
    <title>Homelab Nginx</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        h1 {
            color: #333;
        }
    </style>
</head>
<body>
    <h1>Hello from Homelab!</h1>
    <p>This is a simple Nginx server running on Nomad.</p>
    <p>Node: {{ env "node.unique.name" }}</p>
    <p>Allocated Resources:</p>
    <ul>
        <li>CPU: {{ env "NOMAD_CPU_LIMIT" }} MHz</li>
        <li>Memory: {{ env "NOMAD_MEMORY_LIMIT" }} MB</li>
    </ul>
</body>
</html>
EOH
      }
      
      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}
```

## Troubleshooting

### Common Issues

1. **Consul not forming a cluster**:
   - Check network connectivity between nodes
   - Verify the Consul encryption key is the same on all nodes
   - Check firewall rules for ports 8300-8302

2. **Nomad jobs failing to start**:
   - Check Nomad logs: `journalctl -u nomad`
   - Verify Docker is running: `systemctl status docker`
   - Check resource constraints

3. **Caddy not serving sites**:
   - Check Consul for registered services
   - Verify Consul-Template is running: `systemctl status consul-template`
   - Check Caddy logs: `journalctl -u caddy`

4. **Cloudflare tunnel not working**:
   - Check cloudflared logs: `journalctl -u cloudflared`
   - Verify tunnel credentials are correct
   - Check DNS records in Cloudflare

## Security Considerations

1. **Firewall**: Configure a firewall on all nodes to restrict access
   ```bash
   # Example UFW setup
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw allow from 10.0.1.0/24 to any port 22 proto tcp # SSH
   sudo ufw allow from 10.0.1.0/24 to any port 4646 proto tcp # Nomad HTTP
   sudo ufw allow from 10.0.1.0/24 to any port 4647 proto tcp # Nomad RPC
   sudo ufw allow from 10.0.1.0/24 to any port 4648 proto tcp # Nomad Serf
   sudo ufw allow from 10.0.1.0/24 to any port 8300:8302 proto tcp # Consul
   sudo ufw allow from 10.0.1.0/24 to any port 8301:8302 proto udp # Consul
   sudo ufw allow from 10.0.1.0/24 to any port 8500 proto tcp # Consul HTTP
   sudo ufw allow from 10.0.1.0/24 to any port 8600 proto tcp # Consul DNS
   sudo ufw allow from 10.0.1.0/24 to any port 8200 proto tcp # Vault
   sudo ufw enable
   ```

2. **HTTPS**: All services should be accessed via HTTPS only

3. **Vault**: 
   - Store unseal keys securely and separately
   - Rotate Vault root tokens periodically
   - Use Vault for secret management across your infrastructure

4. **Updates**: Keep all systems and containers updated
   ```bash
   # Update system packages
   sudo apt update && sudo apt upgrade -y
   
   # Update container images
   nomad job run -detach your-service.nomad
   ```

5. **LDAP Security**: If using LDAP for authentication:
   - Use TLS for LDAP connections
   - Implement least privilege access
   - Regularly audit user accounts

## Maintenance

### Updating the Cluster

```bash
# Update system packages
ansible-playbook -i hosts.yml site.yml --tags bootstrap

# Update Nomad/Consul/Vault
ansible-playbook -i hosts.yml site.yml --tags nomad,consul,vault
```

### Checking Cluster Status

```bash
# Check Nomad status
nomad status

# Check Consul members
consul members

# Check Vault status
vault status
```

### Backing Up Configuration

Regularly back up the following:

1. Vault unseal keys and root token
2. Consul KV store: `consul kv export > consul-backup.json`
3. Nomad job specifications: `nomad job history -json <job> > job-backup.json`
4. Application data (according to your storage solution)

## Software Versions

This configuration uses the following software versions:
- Nomad: 1.6.0 (consider upgrading to the latest stable version)
- Consul: 1.16.0 (consider upgrading to the latest stable version)
- Vault: 1.14.0 (consider upgrading to the latest stable version)
- Caddy: Latest (via Ansible role)
- Cloudflared: Latest (via Ansible role)

## Additional Resources

- [Nomad Documentation](https://www.nomadproject.io/docs)
- [Consul Documentation](https://www.consul.io/docs)
- [Vault Documentation](https://www.vaultproject.io/docs)
- [Caddy Documentation](https://caddyserver.com/docs)
- [Cloudflare Tunnels Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- HashiCorp for Nomad, Consul, and Vault
- The Caddy team for an excellent web server
- Cloudflare for their tunneling service 