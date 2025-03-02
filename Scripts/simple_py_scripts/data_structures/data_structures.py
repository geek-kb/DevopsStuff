class Node:
    """A simple linked list node class."""
    def __init__(self, value):
        self.value = value
        self.next = None

def data_structures_example() -> None:
    """Demonstrates basic usage of Python data structures."""
    my_list = [1, 2, 3]
    my_set = {1, 2, 3}
    my_tuple = (1, 2, 3)
    my_dict = {'name': 'Alice', 'age': 30}

    print(my_list, my_set, my_tuple, my_dict)

    node1 = Node(1)
    node2 = Node(2)
    node1.next = node2
    print(node1.next.value)

data_structures_example()
