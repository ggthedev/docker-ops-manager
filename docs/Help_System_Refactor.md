# Help System Refactor

## Overview

The help system in Docker Ops Manager has been refactored to provide a centralized, consistent, and maintainable approach to displaying help information.

## Architecture

### Centralized Help Functions

All help-related functions are now centralized in `lib/args_parser.sh`:

1. **`print_help()`** - Main help function for general usage
2. **`print_command_help()`** - Command-specific help function

### Function Locations

- **Primary Location**: `lib/args_parser.sh` - Contains all help functions
- **Usage**: `docker-manager.sh` calls these functions when help is requested
- **Removed**: Duplicate `print_help()` function from `lib/utils.sh`

## Help Function Details

### print_help()

**Purpose**: Displays general help information for the Docker Ops Manager

**Features**:
- Shows all available commands with short descriptions
- Lists all available options with descriptions
- Includes the `--no-start` flag documentation
- Provides usage examples and references

**Output Format**:
```
Usage: ./docker_mgr.sh [COMMAND] [OPTIONS] [ARGUMENTS]

Commands:
  generate|install  -g, (generates the image, generates container, but does not start it)
  update/refresh    -U, (stops if needed, deletes container/image, regenerates image/container)
  ...

Options:
  --help, -h        (shows this help message)
  --version, -v     (shows the version of the tool)
  --no-start        (create container without starting it - generate/install only)
  ...
```

### print_command_help()

**Purpose**: Displays detailed help for specific commands

**Features**:
- Command-specific usage information
- Detailed argument descriptions
- Available options for each command
- Usage examples
- Includes `--no-start` flag for relevant commands

**Supported Commands**:
- `generate` - Container generation from YAML
- `install` - Container installation from state
- `update` - Container updates
- `start` - Container startup
- `restart` - Container restart
- `stop` - Container stopping
- `status` - Container status
- `clean` - Container cleanup
- `list` - Resource listing
- `nuke` - System cleanup
- `env` - Environment information
- `logs` - Container logs

## Cleanup Actions

### Removed Duplicates

1. **Removed from `lib/utils.sh`**:
   - Duplicate `print_help()` function
   - Different format and content that was not being used
   - Eliminated confusion about which help function to use

### Maintained Functions

1. **Kept in `lib/args_parser.sh`**:
   - `print_help()` - Main help function
   - `print_command_help()` - Command-specific help
   - All help-related logic and formatting

## Usage Patterns

### General Help
```bash
./docker-manager.sh help
./docker-manager.sh --help
./docker-manager.sh -h
```

### Command-Specific Help
```bash
./docker-manager.sh help generate
./docker-manager.sh help install
./docker-manager.sh help start
```

### Short Option Help
```bash
./docker-manager.sh help -g  # Same as help generate
./docker-manager.sh help -i  # Same as help install
```

## Benefits of Centralization

1. **Single Source of Truth**: All help information is in one place
2. **Consistency**: Uniform formatting and style across all help output
3. **Maintainability**: Changes to help content only need to be made in one file
4. **No Confusion**: Eliminates duplicate functions that could cause conflicts
5. **Clear Ownership**: `args_parser.sh` is the logical home for help functions

## Implementation Details

### Function Calls

The main script (`docker-manager.sh`) calls help functions as follows:

```bash
# In route_operation() function
"help")
    if [[ ${#CONTAINER_NAMES[@]} -gt 0 ]]; then
        # Command-specific help
        local command="${CONTAINER_NAMES[0]}"
        print_command_help "$command"
    else
        # General help
        print_help
    fi
    ;;
```

### Argument Parsing

Help requests are handled in the argument parser:

```bash
--help|-h)
    print_help
    exit 0
    ;;
```

## Testing

The help system is tested through:

1. **Manual Testing**: Running help commands and verifying output
2. **Test Scripts**: `tests/test_help_refactor.sh` validates help functionality
3. **Integration**: Help functions work with the argument parsing system

## Future Enhancements

### Planned Improvements

1. **Interactive Help**: Consider adding interactive help mode
2. **Context-Sensitive Help**: Show relevant help based on current state
3. **Help Categories**: Group commands by functionality
4. **Search Functionality**: Allow searching help content

### Example Future Features

```bash
# Interactive help
./docker-manager.sh help --interactive

# Context-sensitive help
./docker-manager.sh help --context

# Search help
./docker-manager.sh help --search "container"
```

## Migration Notes

### From Previous Versions

- **No Breaking Changes**: Help functionality remains the same
- **Improved Consistency**: All help output now uses the same format
- **Better Organization**: Help functions are properly organized
- **Eliminated Duplicates**: No more confusion about which help function to use

### For Developers

- **Help Functions**: Only modify help content in `lib/args_parser.sh`
- **New Commands**: Add help information to `print_command_help()` function
- **Formatting**: Follow the established pattern for consistency
- **Testing**: Update tests if help content changes

## Conclusion

The centralized help system provides a clean, maintainable, and consistent approach to displaying help information. By eliminating duplicates and centralizing all help-related functions in `lib/args_parser.sh`, the system is now easier to maintain and extend while providing a better user experience. 