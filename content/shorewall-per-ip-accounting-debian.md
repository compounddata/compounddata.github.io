---
title: "Shorewall per Ip Accounting Debian"
date: 2022-08-10T08:38:31+10:00
draft: true
---

Install xtables and kernel headers:
```bash
$ sudo apt install dev-scripts linux-headers-`uname -r` xtables-addons-common xtables-addons-source xtables-addons-dkms
```

xtables-addons-dkms fails to build. Most likely due to https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1014680.

Build the package:
```bash
$ cd xtables-addons-3.21
$ debuild -b -uc -us
```

In the parent directory you should now have 4 deb packages:
```shell
$ ls -1 *.deb
xtables-addons-common-dbgsym_3.21-1_arm64.deb
xtables-addons-common_3.21-1_arm64.deb
xtables-addons-dkms_3.21-1_all.deb
xtables-addons-source_3.21-1_all.deb
```

Install the `xtables-addons-dkms` and xtables-addons-common` packages:
```shell
$ sudo dpkg -i xtables-addons-dkms_3.21-1_all.deb xtables-addons-common_3.21-1_arm64.deb
```

This will build the xtables-addons kernel modules within `/lib/modules/$(uname -r)/updates/dkms`:
```shell
$ ls -1 /lib/modules/$(uname -r)/updates/dkms/xt_*.ko  
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_ACCOUNT.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_CHAOS.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_DELUDE.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_DHCPMAC.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_DNETMAP.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_ECHO.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_IPMARK.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_LOGMARK.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_PROTO.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_SYSRQ.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_TARPIT.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_condition.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_fuzzy.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_geoip.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_iface.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_ipp2p.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_ipv4options.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_length2.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_lscan.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_pknock.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_psd.ko
/lib/modules/5.14.0-0.bpo.2-arm64/updates/dkms/xt_quota2.ko
```

Add the accounting config to `/etc/shorewall/accounting`:
```shell
ACCOUNT(int-ext,10.0.1.0/24)    -   eth1    eth0
ACCOUNT(int-ext,10.0.1.0/24)    -   eth0    eth1
```
