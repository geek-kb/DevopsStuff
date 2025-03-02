def logging_decorator(func):
    """Decorator that logs function calls."""
    def wrapper(*args, **kwargs):
        print(f'Calling {func.__name__}')
        return func(*args, **kwargs)
    return wrapper

@logging_decorator
def say_hello() -> None:
    """Prints a greeting message."""
    print('Hello!')

say_hello()
