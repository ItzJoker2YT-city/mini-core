# v0.1.0 release validation

Tests were performed against the exact release base through disposable QCOW2
overlays. The configured user VM and its credentials were not used as the export.

| Check | Result |
| --- | --- |
| BIOS disk boot, with no external kernel/initrd | Pass |
| Rust PID 1, virtio disk/network, one CPU, 128 MiB RAM | Pass |
| First-boot server-name selection and validation | Pass |
| Hidden password entry and normal-user console login | Pass |
| Username whitespace handling and existing-name rejection | Pass |
| SSH unavailable before setup and available after setup | Pass |
| Chosen-account SSH password login and sudo authentication | Pass |
| Root password locked; no default root password hash | Pass |
| Chosen hostname and account persist after power cycle | Pass |
| GNU Wget HTTPS with certificate verification | Pass |
| No lighttpd process or calculator HTTP port 8080 listener | Pass |
| ext4 filesystem check and QCOW2 integrity | Pass |
| Raw/QCOW2 block comparison | Pass |
| No configured test account, SSH host keys, or maintenance authorized key | Pass |
| Access-credential scan | Pass |
| Exact Debian source versions and source-file checksums | Pass |
| Custom script shell-syntax checks | Pass |

The credential scan distinguishes actual access credentials from the public
cryptographic self-test fixtures embedded in the unmodified Debian GnuTLS library.
Those fixtures were matched to its corresponding upstream source and stock
package checksum; they are not usable user/SSH/GitHub credentials.

This is functional testing, not a security audit or certification for arbitrary
VPS providers, hypervisors or workloads. No fixed CPU percentage, zero-memory
claim, or bit-reproducible-build guarantee is made. The rebuild recipe has syntax
checks but has not been certified as a full fresh build on every host version.
