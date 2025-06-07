# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of AudioCapture macOS App
- Real-time audio capture from microphone and system audio
- HTTP API server with health check and configuration endpoints
- WebSocket support for real-time audio streaming
- Native macOS GUI application
- Command-line interface support
- Comprehensive Makefile for build automation

### Features
- **Audio Capture**: Simultaneous capture of microphone and system audio
- **WebSocket Streaming**: Real-time audio data transmission via WebSocket
- **HTTP API**: RESTful endpoints for health checks and configuration
- **Cross-Platform**: Support for both GUI and CLI modes
- **High Precision**: Double precision audio data (64-bit floating point)
- **Stereo Support**: Proper stereo audio mixing for system audio

### Technical Details
- Built with Swift 5.9 and Vapor framework
- Uses AVFoundation for audio capture
- ScreenCaptureKit integration for system audio (macOS 12.3+)
- WebSocket-based real-time data streaming
- JSON-formatted audio data packets

### System Requirements
- macOS 13.0 or later
- Microphone access permission
- Screen recording permission (for system audio)

## [2.1.0] - 2024-12-XX

### Fixed
- ✅ **Signal 5 Crash**: Fixed server stop/restart functionality
- ✅ **LoggingSystem**: Prevented multiple initialization crashes
- ✅ **Resource Management**: Proper cleanup of WebSocket connections and audio streams
- ✅ **Audio Precision**: Upgraded from Float32 to Double precision
- ✅ **Stereo Audio**: Fixed system audio channel mixing (left + right channels)

### Improved
- Server stop functionality now only stops the service, not the entire application
- Support for multiple stop/start cycles without crashing
- Better error handling and logging
- Improved async/await patterns for server lifecycle management

### Known Issues
- Speech recognition service temporarily removed due to permission conflicts

## [2.0.0] - Initial Development

### Added
- Core audio capture functionality
- Basic HTTP server with Vapor
- WebSocket support
- Initial GUI implementation

### Issues Resolved in Later Versions
- System audio data returning all zeros (stereo channel issue)
- Audio precision limitations (Float vs Double)
- Server crash on stop (Signal 5)
- Resource cleanup issues 