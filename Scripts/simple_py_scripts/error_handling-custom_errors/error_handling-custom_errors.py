class CustomError(Exception):
    """Custom exception class for demonstrating error handling."""
    pass

def error_handling_example() -> None:
    """Raises and handles a custom exception."""
    try:
        raise CustomError("This is a custom exception")
    except CustomError as e:
        print(f"Caught an error: {e}")
    finally:
        print("This always runs")

error_handling_example()
