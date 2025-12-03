# Troubleshooting

## Table of Contents

- [SSL/Certificate Errors](#sslcertificate-errors)
- [Kali Repository Blocked](#kali-repository-blocked)
- [UTM Plugin Issues](#utm-plugin-issues)

---

This guide covers common issues you might encounter when setting up or using the VM, along with their solutions.

## SSL/Certificate Errors

If you see SSL certificate verification errors during provisioning:

1. **Corporate Proxy**: Place your company's root CA certificate in `config/*.crt`
2. **Vagrant SSL Issues**: If Vagrant itself has SSL issues, append your certificate to Vagrant's CA bundle:

   ```bash
   # Find Vagrant's cacert.pem
   # macOS: /opt/vagrant/embedded/cacert.pem

   # Append your certificate
   cat /path/to/your-ca.crt >> /opt/vagrant/embedded/cacert.pem
   ```

## Kali Repository Blocked

Corporate networks may block access to Kali repositories. The provisioning script:

1. Tries multiple university mirrors first
2. Falls back to the bundled GPG keyring if downloads fail

If all mirrors are blocked, ask your IT team to whitelist one of:

- `ftp.halifax.rwth-aachen.de`
- `mirror.karneval.cz`
- `ftp.acc.umu.se`

## UTM Plugin Issues

If you encounter issues with the vagrant_utm plugin:

```bash
# Reinstall the plugin
vagrant plugin uninstall vagrant_utm
vagrant plugin install vagrant_utm

# Check plugin version
vagrant plugin list
```

---

## See Also

- [SSL Inspection & Proxies](ssl_inspection_and_proxies.md) — Detailed certificate setup guide
- [Configuration](configuration.md) — Environment variables and proxy settings
- [Technical Details](technical_details.md) — How the provisioning pipeline works
