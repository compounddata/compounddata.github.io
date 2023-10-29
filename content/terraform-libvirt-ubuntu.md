---
title: "Using the terraform libvirt provider to provision an Ubuntu 20.04 guest"
date: 2020-12-28T11:04:50+11:00
draft: true
---

# Introduction

This HOWTO describes how to use the [terraform libvirt provider](https://github.com/dmacvicar/terraform-provider-libvirt) to provision an Ubuntu 20.04 guest.

# Prerequisites

 - go >= 1.13 
 - terraform >= 0.13 
 - a system running libvirtd

# Install terraform-provider-libvirt

Download the source for the terraform libvirt provider and build the plugin:
```text
$ git clone git@github.com:dmacvicar/terraform-provider-libvirt.git
$ cd terraform-provider-libvirt
$ git checkout v0.6.3
$ make build
```

This will produce a `terraform-provider-libvirt` file which needs to be moved into a directory under `~/.local`:

```text
$ mkdir -p ~/.local/share/terraform/plugins/registry.terraform.io/dmacvicar/libvirt/0.6.3/linux_amd64
$ mv terraform-provider-libvirt ~/.local/share/terraform/plugins/registry.terraform.io/dmacvicar/libvirt/0.6.3/linux_amd64/
```

# Download the Ubuntu cloud image

Download the [focal-server-cloudimg-amd64-disk-kvm.img](https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64-disk-kvm.img) image:
```text
$ wget https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64-disk-kvm.img
```

# Create terraform resources 

_The following terraform config can exist within a single `main.tf` file._

Create the [terraform](https://www.terraform.io/docs/configuration/terraform.html) configuration resource block to define the minimum terraform version and required providers:
```text
terraform {
 required_version = ">= 0.13"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.6.3"
    }
  }
}
```

Create a [provider](https://www.terraform.io/docs/configuration/providers.html) configuration which defines how terraform will connect to libvirtd:
```text
provider "libvirt" {
  uri = "qemu:///system"
}
```

Setup a `pool` and `volume`, used to store the Ubuntu 20.04 cloud image:
```text
resource "libvirt_pool" "ubuntu20" {
  name = "ubuntu20"
  type = "dir"
  path = "./terraform-provider-libvirt-pool-ubuntu"
}

resource "libvirt_volume" "ubuntu20" {
  name   = "ubuntu20"
  pool   = libvirt_pool.ubuntu20.name
  source = "./focal-server-cloudimg-amd64-disk-kvm.img"
  format = "qcow2"
}
```

At this point, you should be able to run `terraform init` and `terraform apply` to create the pool and volume resources:
```text
$ terraform init
$ terraform apply
```

Using [virsh](https://www.libvirt.org/manpages/virsh.html), you can confirm that both resources have been created:
```text
$ virsh pool-info ubuntu20
Name:           ubuntu20
UUID:           558f8e2c-b9cb-46e6-9311-6468531322a8
State:          running
Persistent:     yes
Autostart:      yes
Capacity:       68.17 GiB
Allocation:     45.58 GiB
Available:      22.59 GiB
```
```text
$ virsh vol-info --pool ubuntu20 ubuntu20
Name:           ubuntu20
Type:           file
Capacity:       2.20 GiB
Allocation:     528.44 MiB
```

Create a `user_data.cfg` file, adding a user to allow you to login:

```text
#cloud-config
ssh_pwauth: True
users:
  - name: user1
    groups: sudo
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    plain_text_passwd: passw0rd
    lock_passwd: false
```

Create a `network_config.cfg` file which will be used by the guest for network configuration:
```text
version: 2
ethernets:
  ens3:
    dhcp4: true
```

Create a `meta_data.cfg` file which will be used to pass in data to cloudinit:
```text
local-hostname: ubuntu20.local
```

Using terraforms [templatefile](https://www.terraform.io/docs/configuration/functions/templatefile.html) function to render the `user_data.cfg`, `network_config.cfg` and `meta_data.cfg` files, create a libvirt_cloudinit_disk:
```text
resource "libvirt_cloudinit_disk" "commoninit" {
  name           = "commoninit.iso"
  user_data      = templatefile("${path.module}/user_data.cfg", {})
  network_config = templatefile("${path.module}/network_config.cfg", {})
  meta_data      = templatefile("${path.module}/meta_data.cfg", {})
  pool           = libvirt_pool.ubuntu20.name
}
```

See the [How libvirt_cloudinit_disk works](#how-libvirt_cloudinit_disk-works) if you're curious on how the libvirt_cloudinit_disk works with cloudinit.

Create a network, the guest domain using the `libvirt_domain` resource and an `output` resource that provides us with the guests IP address:
```text
resource "libvirt_network" "lab" {
  name      = "lab"
  domain    = "lab.local"
  mode      = "nat"
  addresses = ["10.0.100.0/24"]
}

resource "libvirt_domain" "ubuntu20" {
  name   = "ubuntu20"
  memory = "512"
  vcpu   = 1

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    network_name   = "lab"
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  disk {
    volume_id = libvirt_volume.ubuntu20.id
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

output "ip" {
  value = libvirt_domain.ubuntu20.network_interface[0].addresses[0]
}
```

Initialize the terraform config and apply:
```text
$ terraform init
$ terraform apply
```

Grab the IP address from the output of `terraform apply` or `terraform refresh` and SSH using the account created within `user_data.cfg`:
```text
$ ssh user1@10.0.100.66
```

# Using make to call terraform

You can use [make](https://www.gnu.org/software/make/) to help re-create the terraform resources with a single command. 

Consider this `Makefile`:
```text
#!/usr/bin/env make

all: terraform-destroy terraform-apply

terraform-apply: terraform-init
	terraform apply -auto-approve

terraform-destroy: terraform-init
	terraform destroy -auto-approve

terraform-init:
	terraform init

.PHONY: all terraform-apply terraform-destroy terraform-init
```

Running the single command `make` will now destroy and re-create the terraform resources.


# How libvirt_cloudinit_disk works

The `libvirt_cloudinit_disk` resource creates an [ISO 9660](https://en.wikipedia.org/wiki/ISO_9660) file using `mkisofs` and uploads the file to the `ubuntu20` `pool` as a `volume`. 

`mkisofs` doesn't ship with Debian 10, so if you're host system is running Debian 10, you will have to provide an alternative:
```text
$ sudo apt install xorriso 
$ sudo update-alternatives --install /usr/bin/mkisofs mkisofs /usr/bin/xorrisofs 10
```

The ISO 9660 file is mounted as a _cdrom_ device within the guest domain:
```text
$ virsh dumpxml ubuntu20
[...]
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='./terraform-provider-libvirt-pool-ubuntu/commoninit.iso'/>
      <backingStore/>
      <target dev='hdd' bus='ide'/>
      <readonly/>
      <alias name='ide0-1-1'/>
      <address type='drive' controller='0' bus='1' target='0' unit='1'/>
    </disk>
[...]
```

cloudinit allows users to provide user, network and meta data files to the instance using a [NoCloud](https://cloudinit.readthedocs.io/en/latest/topics/datasources/nocloud.html) data source which can be an ISO 9660 filesystem which has the volume label `cidata` or `CIDATA`.

```text
$ blkid /dev/sr0
/dev/sr0: UUID="2021-01-03-01-59-49-00" LABEL="cidata" TYPE="iso9660"
```

This device can be mounted, showing that it contains the `user_data.cfg`, `network_data.cfg` and `meta_data.cfg` files that were rendered by [templatefile](https://www.terraform.io/docs/configuration/functions/templatefile.html):
```text
$ sudo mount /dev/sr0 /media
$ ls -la /media/*
-rwxr-xr-x 1 user1 user1  31 Jan  3 01:59 /media/meta-data
-rwxr-xr-x 1 user1 user1  46 Jan  3 01:59 /media/network-config
-rwxr-xr-x 1 user1 user1 163 Jan  3 01:59 /media/user-data
```

