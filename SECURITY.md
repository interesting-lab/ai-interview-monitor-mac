# Security Policy

## Supported Versions

We provide security updates for the following versions of AudioCapture macOS App:

| Version | Supported          |
| ------- | ------------------ |
| 2.1.x   | :white_check_mark: |
| 2.0.x   | :white_check_mark: |
| < 2.0   | :x:                |

## Reporting a Vulnerability

We take the security of AudioCapture macOS App seriously. If you discover a security vulnerability, please report it to us as described below.

### Where to Report

Please **DO NOT** report security vulnerabilities through public GitHub issues.

Instead, please report security vulnerabilities via:
- **Email**: [security@yourproject.com] (replace with actual email)
- **GitHub Security Advisories**: Use GitHub's private vulnerability reporting feature

### What to Include

When reporting a security vulnerability, please include:

1. **Type of issue** (e.g., buffer overflow, SQL injection, cross-site scripting, etc.)
2. **Full paths of source file(s)** related to the manifestation of the issue
3. **Location of the affected source code** (tag/branch/commit or direct URL)
4. **Step-by-step instructions** to reproduce the issue
5. **Proof-of-concept or exploit code** (if possible)
6. **Impact of the issue**, including how an attacker might exploit it

### Response Timeline

- **Initial Response**: Within 48 hours of receiving the report
- **Assessment**: Within 1 week of initial response
- **Fix Development**: Varies based on complexity and severity
- **Public Disclosure**: After fix is released and users have had time to update

## Security Considerations

### Audio Data Privacy

AudioCapture macOS App handles sensitive audio data. Key security considerations:

- **Local Processing**: All audio processing is performed locally on the device
- **Network Transmission**: Audio data is transmitted via WebSocket connections
- **Data Storage**: No audio data is permanently stored by the application
- **Permissions**: Requires explicit user consent for microphone and screen recording access

### Network Security

- **localhost Only**: By default, the server only binds to localhost (127.0.0.1)
- **No Authentication**: Current version does not implement authentication (consider this for production use)
- **WebSocket Security**: Uses standard WebSocket protocol without additional encryption

### System Permissions

The application requires:
- **Microphone Access**: For capturing microphone audio
- **Screen Recording**: For capturing system audio (macOS 12.3+)

These permissions are granted through macOS system dialogs and can be revoked at any time in System Preferences.

## Security Best Practices

### For Users

1. **Verify Source**: Only download from official sources
2. **Check Permissions**: Review requested permissions before granting access
3. **Network Monitoring**: Monitor network connections if concerned about data transmission
4. **Regular Updates**: Keep the application updated to receive security fixes

### For Developers

1. **Code Review**: All code changes should be reviewed for security implications
2. **Dependency Management**: Regularly update dependencies to patch security vulnerabilities
3. **Input Validation**: Validate all inputs, especially those from network sources
4. **Error Handling**: Avoid exposing sensitive information in error messages

## Known Security Limitations

1. **No Encryption**: WebSocket communication is not encrypted by default
2. **No Authentication**: No built-in user authentication mechanism
3. **localhost Binding**: While safer, this may limit legitimate remote access scenarios

## Reporting Security Issues in Dependencies

If you discover security vulnerabilities in our dependencies:

1. Check if the vulnerability has already been reported to the dependency maintainer
2. If not, report it to the dependency maintainer first
3. Also report it to us so we can track and update our dependencies

## Security Updates

Security updates will be:
- Released as soon as possible after verification
- Documented in CHANGELOG.md with security advisory labels
- Announced through GitHub releases and security advisories

## Contact

For security-related questions or concerns:
- **Security Email**: [security@yourproject.com] (replace with actual email)
- **General Issues**: Use GitHub issues for non-security related bugs

Thank you for helping keep AudioCapture macOS App and its users safe! 