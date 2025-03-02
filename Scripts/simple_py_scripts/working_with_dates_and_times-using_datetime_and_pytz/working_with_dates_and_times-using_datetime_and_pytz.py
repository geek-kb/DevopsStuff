from datetime import datetime, timedelta

def date_time_example() -> None:
    """Demonstrates date and time manipulation using datetime module."""
    now = datetime.now()
    print(now.strftime("%Y-%m-%d %H:%M:%S"))

    future = now + timedelta(days=5)
    print(f"Future date: {future.strftime('%Y-%m-%d')}")

date_time_example()
