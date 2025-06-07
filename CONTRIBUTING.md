# Contributing to AudioCapture macOS App

Thank you for your interest in contributing to AudioCapture macOS App! This document provides guidelines for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Reporting Issues](#reporting-issues)

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally
3. Set up the development environment
4. Create a feature branch
5. Make your changes
6. Test your changes
7. Submit a pull request

## Development Setup

### Prerequisites

- macOS 13.0 or later
- Xcode 14.0 or later
- Swift 5.9 or later
- Swift Package Manager (included with Xcode)

### Setup Instructions

```bash
# Clone your fork
git clone https://github.com/yourusername/audiocapture-macos.git
cd audiocapture-macos

# Build the project
make build

# Run tests
make test

# Run the application
make debug
```

### Development Tools

We recommend using:
- **Xcode**: Primary IDE for Swift development
- **Swift Package Manager**: For dependency management
- **Make**: For build automation
- **Git**: Version control

## Making Changes

### Branch Naming

Use descriptive branch names:
- `feature/add-new-audio-format`
- `bugfix/fix-websocket-connection`
- `docs/update-api-documentation`
- `refactor/improve-audio-processing`

### Commit Messages

Follow conventional commit format:
```
type(scope): description

[optional body]

[optional footer]
```

Examples:
- `feat(audio): add support for 32-bit audio format`
- `fix(websocket): resolve connection timeout issues`
- `docs(readme): update installation instructions`
- `refactor(capture): simplify audio buffer processing`

## Pull Request Process

1. **Update Documentation**: Ensure all changes are documented
2. **Add Tests**: Include tests for new functionality
3. **Update Changelog**: Add entry to CHANGELOG.md
4. **Check Build**: Ensure the project builds successfully
5. **Code Review**: Request review from maintainers

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Manual testing performed
- [ ] All tests pass

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Changelog updated
```

## Coding Standards

### Swift Style Guide

Follow Apple's Swift API Design Guidelines:

1. **Naming Conventions**:
   - Use `camelCase` for variables and functions
   - Use `PascalCase` for types and protocols
   - Use descriptive names

2. **Code Organization**:
   - Group related functionality together
   - Use extensions for protocol conformance
   - Add MARK comments for organization

3. **Documentation**:
   - Use Swift documentation comments (`///`)
   - Document public APIs
   - Include parameter and return value descriptions

### Example Code Style

```swift
/// Captures audio data from the specified source
/// - Parameter audioType: The type of audio to capture (mic or system)
/// - Returns: A stream of audio data samples
func captureAudio(from audioType: AudioType) async throws -> AsyncStream<AudioData> {
    // Implementation
}
```

### File Organization

```
Sources/
├── AudioCaptureMacApp/
│   ├── Audio/          # Audio capture and processing
│   ├── Network/        # HTTP and WebSocket handling
│   ├── GUI/           # User interface components
│   ├── Utils/         # Utility functions and extensions
│   └── main.swift     # Application entry point
```

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run specific test suite
swift test --filter AudioCaptureTests

# Run with coverage
swift test --enable-code-coverage
```

### Test Guidelines

1. **Unit Tests**: Test individual components in isolation
2. **Integration Tests**: Test component interactions
3. **Manual Tests**: Test GUI and audio functionality
4. **Performance Tests**: Ensure audio latency requirements

### Writing Tests

```swift
import XCTest
@testable import AudioCaptureMacApp

final class AudioCaptureTests: XCTestCase {
    func testAudioCapture() async throws {
        // Test implementation
    }
}
```

## Reporting Issues

### Before Reporting

1. Check existing issues
2. Search documentation
3. Try latest version
4. Gather system information

### Issue Template

```markdown
**Description**
Clear description of the issue

**Steps to Reproduce**
1. Step one
2. Step two
3. Step three

**Expected Behavior**
What should happen

**Actual Behavior**
What actually happens

**Environment**
- macOS version:
- Xcode version:
- App version:

**Logs**
Include relevant log output
```

### Bug Report Types

- **Crash**: Application crashes or freezes
- **Audio Issue**: Problems with audio capture or quality
- **API Issue**: HTTP/WebSocket API problems
- **GUI Issue**: User interface problems
- **Performance**: Latency or resource usage issues

## Areas for Contribution

### High Priority
- Audio format support improvements
- WebSocket connection stability
- Performance optimizations
- Error handling improvements

### Documentation
- API documentation
- Code comments
- User guides
- Example implementations

### Features
- Additional audio formats
- Configuration options
- Logging improvements
- Cross-platform support

## Getting Help

- **Issues**: Use GitHub issues for bug reports
- **Discussions**: Use GitHub discussions for questions
- **Documentation**: Check README and wiki
- **Code Review**: Request review from maintainers

Thank you for contributing to AudioCapture macOS App! 