# test_openai Documentation

<!-- BEGIN_PY_DOCS -->
## questions.py

### Functions

#### `__init__(self)`

Initializes the CLIHandler, sets up argument parsing, and processes user inputs.


#### `validate_args(self)`

Validates the command-line arguments to ensure supported levels and languages are used.

Raises:
    ValueError: If an unsupported level or language is provided.

Returns:
    str: A formatted prompt for OpenAI based on the user input.


#### `execute_request(self, content)`

Sends a request to OpenAI to generate coding exercises and processes the response.

Args:
    content (str): The formatted prompt for OpenAI.


<!-- END_PY_DOCS -->