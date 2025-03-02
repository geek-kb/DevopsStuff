import argparse

def create_cli() -> None:
    """Creates a simple command-line interface using argparse."""
    parser = argparse.ArgumentParser(description='Simple CLI Example')
    parser.add_argument('--name', type=str, help='Your name')
    args = parser.parse_args()
    print(f'Hello, {args.name}!')

# Uncomment the line below to test via CLI
# create_cli()
