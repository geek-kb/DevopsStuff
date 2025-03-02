import pickle

def serialize_data() -> None:
    """Serializes and deserializes data using pickle."""
    data = {'key': 'value'}
    with open('data.pkl', 'wb') as f:
        pickle.dump(data, f)

    with open('data.pkl', 'rb') as f:
        loaded_data = pickle.load(f)
    print(loaded_data)

serialize_data()
