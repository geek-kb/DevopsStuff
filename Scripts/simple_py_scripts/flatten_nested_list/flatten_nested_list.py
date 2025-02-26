input_list = [1, [2, [3, 4], 5], 6, [7 , [8, 9], 10]]

def flatten(input_list):
    flat_list = []
    for i in input_list:
        if isinstance(i, list):
            flat_list.extend(flatten(i))
        else:
            flat_list.append(i)
    return(flat_list)

print(flatten(input_list))
