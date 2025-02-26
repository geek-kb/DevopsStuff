from datetime import datetime

def flatten(lst):
    flat_list = []
    for element in lst:
        if isinstance(element, list):
            flat_list.extend(flatten(element))
        else:
            flat_list.append(element)
    return flat_list

def logger(func):
    def wrapper(*args):
        lines = []
        now = datetime.now()
        time_fmt = now.strftime('%d/%m/%y %H:%M:%S')
        for arg in args:
            if isinstance(arg, list):
                flattened = flatten(arg)
                for item in flattened:
                    log_line = f"{time_fmt} {item}"
                    lines.append(log_line)
            else:
                log_line = f"{time_fmt} {arg}"
                lines.append(log_line)
        return func(lines)
    return wrapper

@logger
def pt(text):
    print("\n".join(text))

pt("Hello", ["nested", ["list", "example"]])
