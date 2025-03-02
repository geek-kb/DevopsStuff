class Singleton:
    """A Singleton class ensuring only one instance is created."""
    _instance = None

    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            cls._instance = super(Singleton, cls).__new__(cls, *args, **kwargs)
        return cls._instance

def singleton_example() -> None:
    """Demonstrates the singleton pattern in action."""
    singleton1 = Singleton()
    singleton2 = Singleton()
    print(singleton1 is singleton2)

singleton_example()
