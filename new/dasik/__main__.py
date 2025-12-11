import argparse
import sys
from pathlib import Path

from dasik.lib.actions.actions_handler import ActionsHandler


def parse_arguments():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        prog='dasik',
        description='Arch Linux installation and configuration tool',
        epilog='Example: dasik config.json'
    )
    
    parser.add_argument(
        'config',
        type=str,
        help='Path to the JSON configuration file'
    )
    
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Enable verbose output'
    )
    
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be done without making changes'
    )
    
    parser.add_argument(
        '--version',
        action='version',
        version='%(prog)s 0.1.0'
    )
    
    return parser.parse_args()


def validate_config_file(config_path: str) -> Path:
    """Validate that the config file exists and is readable."""
    path = Path(config_path)
    
    if not path.exists():
        print(f"Error: Configuration file '{config_path}' does not exist.", file=sys.stderr)
        sys.exit(1)
    
    if not path.is_file():
        print(f"Error: '{config_path}' is not a file.", file=sys.stderr)
        sys.exit(1)
    
    if not path.suffix == '.json':
        print(f"Warning: Configuration file '{config_path}' does not have .json extension.", file=sys.stderr)
    
    return path


def main():
    """Main entry point for the dasik application."""
    args = None
    try:
        args = parse_arguments()
        
        # Validate configuration file
        config_path = validate_config_file(args.config)
        
        if args.verbose:
            print(f"Loading configuration from: {config_path}")
        
        if args.dry_run:
            print("Running in dry-run mode (no changes will be made)")
            # TODO: Implement dry-run mode in ActionsHandler
        
        # Initialize the actions handler with the configuration
        _handler = ActionsHandler(str(config_path))
        
        if args.verbose:
            print("Configuration loaded successfully")
        
        return 0
        
    except KeyboardInterrupt:
        print("\nOperation cancelled by user.", file=sys.stderr)
        return 130
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        if args and args.verbose:
            import traceback
            traceback.print_exc()
        return 1


if __name__ == "__main__":
    exit(main())