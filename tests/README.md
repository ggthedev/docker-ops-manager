# Docker Ops Manager - Test Suite

This directory contains a comprehensive test suite for the Docker Ops Manager, designed to validate functionality, performance, security, and integration aspects of the system.

## Test Structure

The test suite is organized into the following categories:

### Unit Tests (`unit/`)
- **test_config_validation.sh**: Tests configuration loading, validation, and management
- **test_yaml_parser.sh**: Tests YAML parsing, validation, and manipulation

### Integration Tests (`integration/`)
- **test_container_operations.sh**: Tests integration between container operations and other components

### Functional Tests (`functional/`)
- **test_complete_workflow.sh**: Tests complete end-to-end workflows

### Performance Tests (`performance/`)
- **test_load_performance.sh**: Tests system performance under various load conditions

### Security Tests (`security/`)
- **test_security_validation.sh**: Tests security aspects and validation

## Quick Start

### Prerequisites

1. **Docker**: Ensure Docker is installed and running
2. **bc**: Required for performance calculations
   ```bash
   # macOS
   brew install bc
   
   # Ubuntu/Debian
   sudo apt-get install bc
   ```

### Running Tests

#### Run All Tests
```bash
cd docker-ops-manager/tests
./test_runner.sh
```

#### Run Specific Test Categories
```bash
# Run only unit tests
./test_runner.sh unit

# Run unit and integration tests
./test_runner.sh unit integration

# Run performance tests only
./test_runner.sh performance
```

#### Test Options
```bash
# Clean test artifacts before running
./test_runner.sh --clean

# Enable verbose output
./test_runner.sh --verbose

# Run specific categories with options
./test_runner.sh --clean --verbose unit integration
```

## Test Configuration

The test suite uses `test_config.sh` for configuration settings:

- **Test timeouts**: Default timeouts for different test types
- **Performance settings**: Number of containers, iterations, etc.
- **Environment variables**: Test-specific environment configuration
- **Validation settings**: Security and validation parameters

## Test Results

### Output Locations
- **Test Results**: `tests/results/test_results.md`
- **Test Logs**: `tests/logs/`
- **Temporary Files**: `tests/temp/`

### Result Format
Tests generate a comprehensive markdown report including:
- Test summary with pass/fail statistics
- Individual test results with duration and messages
- Performance metrics and benchmarks
- Error details and troubleshooting information

## Test Categories Details

### Unit Tests
Unit tests focus on individual components and functions:
- **Configuration Management**: Loading, validation, environment overrides
- **YAML Processing**: Parsing, validation, field extraction, modification
- **Error Handling**: Invalid inputs, missing files, malformed data

### Integration Tests
Integration tests verify component interactions:
- **Container Lifecycle**: Install, start, stop, restart, cleanup
- **State Management**: State persistence and updates
- **Configuration Integration**: Custom timeouts, force flags, log levels
- **Error Propagation**: Error handling across components

### Functional Tests
Functional tests validate complete workflows:
- **Full Application Deployment**: Multi-service applications
- **Data Persistence**: Volume management and data retention
- **Network Connectivity**: Service communication and isolation
- **Health Monitoring**: Health checks and status reporting

### Performance Tests
Performance tests measure system efficiency:
- **Single Application Performance**: Installation and operation times
- **Multiple Applications**: Concurrent deployment and management
- **Stress Testing**: High container count scenarios
- **Resource Usage**: Memory, CPU, and disk utilization
- **Long-running Stability**: Performance over extended periods

### Security Tests
Security tests validate security measures:
- **Secure Configurations**: Read-only filesystems, dropped capabilities
- **Insecure Detection**: Privileged containers, exposed ports
- **Malicious Prevention**: Command injection, escape vectors
- **Input Validation**: Sanitization and validation
- **Network Security**: Port binding and isolation

## Writing New Tests

### Test Structure
Each test script should follow this structure:

```bash
#!/usr/bin/env bash

# Test: Test name
# Description: Brief description of what the test validates

set -euo pipefail

# Test parameters
PROJECT_ROOT="$1"
TEST_TEMP_DIR="$2"
TEST_LOGS_DIR="$3"

# Test setup
setup_test() {
    echo "Setting up test..."
    # Setup code
}

# Test cleanup
cleanup_test() {
    echo "Cleaning up test..."
    # Cleanup code
}

# Individual test functions
test_specific_functionality() {
    echo "Testing specific functionality..."
    # Test implementation
}

# Main test execution
main() {
    echo "Starting tests..."
    setup_test
    # Run test functions
    cleanup_test
    echo "All tests passed!"
}

main "$@"
```

### Test Guidelines
1. **Isolation**: Each test should be independent and not affect others
2. **Cleanup**: Always clean up resources after tests
3. **Assertions**: Use assertion functions for validation
4. **Documentation**: Include clear descriptions and comments
5. **Error Handling**: Handle errors gracefully and provide useful messages

### Available Assertion Functions
- `assert_equals expected actual message`
- `assert_not_equals expected actual message`
- `assert_contains haystack needle message`
- `assert_not_contains haystack needle message`
- `assert_file_exists file message`
- `assert_file_not_exists file message`
- `assert_directory_exists directory message`
- `assert_exit_code expected actual message`

## Troubleshooting

### Common Issues

#### Docker Not Running
```bash
Error: Docker daemon is not running
```
**Solution**: Start Docker Desktop or Docker daemon

#### Permission Issues
```bash
Error: Permission denied
```
**Solution**: Ensure test scripts are executable
```bash
chmod +x tests/*.sh
chmod +x tests/*/*.sh
```

#### Missing Dependencies
```bash
Error: 'bc' command is required
```
**Solution**: Install bc calculator
```bash
# macOS
brew install bc

# Ubuntu/Debian
sudo apt-get install bc
```

#### Test Timeouts
```bash
Error: Test timed out
```
**Solution**: Increase timeout values in `test_config.sh` or check system resources

### Debug Mode
Enable verbose output for debugging:
```bash
./test_runner.sh --verbose
```

### Individual Test Debugging
Run individual tests directly:
```bash
cd tests/unit
./test_config_validation.sh /path/to/project /path/to/temp /path/to/logs
```

## Continuous Integration

The test suite is designed to work with CI/CD pipelines:

### GitHub Actions Example
```yaml
name: Test Docker Ops Manager
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y bc
      - name: Start Docker
        run: sudo systemctl start docker
      - name: Run tests
        run: |
          cd docker-ops-manager/tests
          ./test_runner.sh --clean
      - name: Upload test results
        uses: actions/upload-artifact@v2
        with:
          name: test-results
          path: docker-ops-manager/tests/results/
```

## Performance Benchmarks

The test suite includes performance benchmarks:

### Expected Performance
- **Single Application Installation**: < 30 seconds
- **Multiple Applications (10)**: < 15 seconds per app
- **Status Check**: < 5 seconds
- **Cleanup**: < 20 seconds
- **Memory Usage**: < 100MB per container
- **CPU Usage**: < 5% per container

### Benchmarking
Run performance tests to measure your system:
```bash
./test_runner.sh performance
```

Results are saved in `tests/results/test_results.md` with detailed metrics.

## Contributing

When adding new tests:

1. Follow the existing test structure and naming conventions
2. Include comprehensive documentation
3. Ensure tests are isolated and clean up after themselves
4. Add appropriate assertions and error handling
5. Update this README if adding new test categories

## Support

For issues with the test suite:
1. Check the troubleshooting section
2. Review test logs in `tests/logs/`
3. Run tests with `--verbose` for detailed output
4. Ensure all prerequisites are met 