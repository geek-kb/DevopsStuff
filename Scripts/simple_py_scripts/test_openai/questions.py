from openai import OpenAI
import argparse
import os
import re

client = OpenAI(
    api_key=os.getenv('OPENAI_API_KEY')
)

class CLIHandler:
    """
    A command-line interface (CLI) tool to generate coding exercises using OpenAI's API.
    
    Attributes:
        parser (argparse.ArgumentParser): The argument parser for CLI inputs.
        args (Namespace): Parsed arguments from the command line.
        questions_bank (list): List to store exercises retrieved from OpenAI.
    """

    def __init__(self):
        """Initializes the CLIHandler, sets up argument parsing, and processes user inputs."""
        self.parser = argparse.ArgumentParser(description="Generates coding exercises from OpenAI")
        self.parser.add_argument("-a", "--amount", help="Amount of exercises", type=int, required=True)
        self.parser.add_argument("-l", "--level", help="Level of exercises", type=str, required=True)
        self.parser.add_argument("-L", "--language", help="Language", type=str, required=True)
        self.args = self.parser.parse_args()

    def validate_args(self):
        """
        Validates the command-line arguments to ensure supported levels and languages are used.

        Raises:
            ValueError: If an unsupported level or language is provided.

        Returns:
            str: A formatted prompt for OpenAI based on the user input.
        """
        self.available_levels = ['simple', 'intermediate', 'hard', 'expert']
        self.available_languages = ['python', 'go']

        if self.args.amount == 1:
            self.content = f"Provide a {self.args.level} exercise in {self.args.language} language"
        elif self.args.amount > 1:
            self.content = f"Provide {self.args.amount} {self.args.level} exercises in {self.args.language} language"

        if self.args.level not in self.available_levels:
            raise ValueError('Supplied level not supported')
        if self.args.language not in self.available_languages:
            raise ValueError('Supplied language not supported')

        return self.content
        
    def execute_request(self, content):
        """
        Sends a request to OpenAI to generate coding exercises and processes the response.

        Args:
            content (str): The formatted prompt for OpenAI.

        The function extracts exercises from the response and stores them in `self.questions_bank`.
        Exercises are split using a delimiter if multiple exercises are provided.
        """
        self.questions_bank = []
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "user", "content": self.content}
            ]
        )

        # Extract message content
        message_dict = response.choices[0].message.model_dump()
        exercise_text = message_dict["content"]

        # Define the delimiter for separating exercises
        delimiter = r"### Exercise \d+"  # Matches "### Exercise 1", "### Exercise 2", etc.

        # Check if multiple exercises exist
        if len(re.findall(delimiter, exercise_text)) > 1:
            exercises = re.split(delimiter, exercise_text)  # Split text based on the delimiter
            self.questions_bank = [ex.strip() for ex in exercises if ex.strip()]  # Remove empty strings and spaces
        else:
            self.questions_bank.append(exercise_text.strip())  # If only one exercise, add it to the list

        # Print the exercises for debugging
        for idx, ex in enumerate(self.questions_bank, 1):
            print(f"Exercise {idx}:\n{ex}\n{'-'*40}")

if __name__ == "__main__":
    cliHandler = CLIHandler()
    content = cliHandler.validate_args()
    cliHandler.execute_request(content)
