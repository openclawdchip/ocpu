# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability within OCPU, please send an email to the maintainers at security@ocpu-project.org instead of creating a public issue.

Please include the following information in your report:

- Type of vulnerability
- Full paths of source file(s) related to the vulnerability
- Location of affected lines of code
- Any special configuration required to reproduce the issue
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the vulnerability

## Response Timeline

We will acknowledge receipt of your vulnerability report within 48 hours and will strive to provide a timeline for a fix within 5 business days.

## Security Best Practices

When using OCPU in your projects:

1. **Regular Updates**: Keep your OCPU version up to date
2. **Access Control**: Limit access to hardware interfaces
3. **Secure Boot**: Use secure boot mechanisms when available
4. **Memory Protection**: Enable all memory protection features
5. **Debug Interfaces**: Disable debug interfaces in production

## Known Limitations

- Side-channel attacks (Spectre/Meltdown) mitigations are planned for future releases
- Formal verification of critical security components is ongoing
