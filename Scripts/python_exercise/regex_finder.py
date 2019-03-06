#!/usr/bin/env python3
"""This Python script searches given file/s or STDIN (if no file has been
provided) for lines matching a given regular expression pattern and
underlines, colors or displays the output in a machine-readable way according
to the user's choice passed by supplied arguments.
Script by Itai Ganot 2019, lel@lel.bz
"""

import re
import argparse
import codecs
import sys


class colored:
    # This class enables wrapping text in color
    BLUE = '\033[94m'
    END = '\033[0m'


def process_no_option(line, i, pattern, regex, file_name):
    # This function simply displays an informational line for
    # each matched text
    message = "Pattern %s was found in %s: line %d. The line is: %s" \
              % (regex, file_name, i + 1, line)
    if re.search(pattern, line):
        print(message, end="")


def process_color_option(line, i, pattern, regex, file_name):
    # This function colors all occurrences of the matching text to
    # the given regex in the line which is in index i in the file file_name
    message = "Pattern %s was found in %s: line %d. The line is: " \
              % (regex, file_name, i+1)
    final_message = message
    line_start = 0
    for match in re.finditer(pattern, line):
        matched_text = line[match.start():match.end()]
        final_message += line[line_start:match.start()] + \
            colored.BLUE + \
            matched_text + \
            colored.END
        line_start = match.end()
    final_message += line[line_start:]
    if line_start > 0:
        print(final_message, end="")


def process_underline_option(line, i, pattern, regex, file_name):
    # This function adds a caret underline (in a new line) below all
    # occurrences of the matching text to the given regex.
    message = "Pattern %s was found in %s: line %d: " \
              % (regex, file_name, i+1)
    underline_message = " " * int(len(message))
    line_start = 0
    for match in re.finditer(pattern, line):
        underline_message += " " * len(line[line_start:match.start()]) + \
                            "^" * len(line[match.start():match.end()])
        line_start = match.end()
    if line_start > 0:
        print(message + line, end="")
        print(underline_message)


def process_machine_option(line, i, pattern, file_name):
    # This function compiles an output formatted by a colon delimiter
    # example: filename:line_number:position:matched_text
    for match in re.finditer(pattern, line):
        matched_text = line[match.start():match.end()]
        print("%s:%d:%d:%s" % (file_name, i+1, match.start(), matched_text))


def process_line(line,
                 i,
                 color,
                 pattern,
                 underline,
                 machine,
                 regex,
                 file_name):
    """This function checks which arguments have been passed to the script
    It then calls to the relevant function.
    #Variables:
    line: line in file to process
    i: index of a processed line
    regex: the regex pattern passed by the user
    pattern: the regex pattern compiled to a regex object
    color: true if user chose to color the results
    underline: true if user chose to underline the results
    machine: true if user chose to display results in machine-readable way
    file_name: file/s passed by the user
    """
    if color:
        process_color_option(line, i, pattern, regex, file_name)
    elif underline:
        process_underline_option(line, i, pattern, regex, file_name)
    elif machine:
        process_machine_option(line, i, pattern, file_name)
    else:
        process_no_option(line, i, pattern, regex, file_name)


def main(files, regex, underline, color, machine):
    """This function is responsible for the processing of the file/s or
    input from STDIN and passing the supplied arguments to
    the process_line function.
    """
    try:
        pattern = re.compile(regex)
    except:
        print("Unable to compile regex")
        return
    if files:
        for file_name in files.split(","):
            try:
                with codecs.open(file_name, 'r', encoding='ascii') as f:
                    for i, line in enumerate(f.readlines()):
                        process_line(line,
                                     i,
                                     color,
                                     pattern,
                                     underline,
                                     machine,
                                     regex,
                                     file_name)
            except:
                print("Error reading file %s" % file_name)
    else:
        for i, line in enumerate(sys.stdin.readlines()):
            process_line(line,
                         i,
                         color,
                         pattern,
                         underline,
                         machine,
                         regex,
                         'stdin')


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Regex finder - \
    finds pattern in file/s or STDIN')
    required_named = parser.add_argument_group('required named argument')
    required_named.add_argument('-r',
                                '--regex',
                                help='regex pattern',
                                required=True)
    parser.add_argument('-f',
                        '--files',
                        help='file(s) to search pattern inside')
    mutual_group = parser.add_argument_group('optional mutually \
    exclusive arguments')
    mutually_exclusive = mutual_group.add_mutually_exclusive_group()
    mutually_exclusive.add_argument('-u',
                                    '--underline',
                                    action='store_true',
                                    help='underlines matched pattern')
    mutually_exclusive.add_argument('-c',
                                    '--color',
                                    action='store_true',
                                    help='colors matched pattern')
    mutually_exclusive.add_argument('-m',
                                    '--machine',
                                    action='store_true',
                                    help='formats output in a \
                                    machine-readable way')
    args = parser.parse_args()
    main(args.files,
         args.regex,
         args.underline,
         args.color,
         args.machine)
