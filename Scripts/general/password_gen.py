#!/usr/bin/env python3
# A script that generates passwords
# -l -> Password length
# -P -> Print password
# -n -> Number of passwords to generate
# Script by Itai Ganot
import random
import argparse
import sys

char_seq = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!#$%&'()*+,-:;<=>?@[]^_`{|}~"


def generate_password(length, passprint):
    password = ""
    for len in range(length):
        random_char = random.choice(char_seq)
        password += random_char

    # print(password)
    list_pass = list(password)
    random.shuffle(list_pass)
    final_password = "".join(list_pass)
    if passprint:
        print(final_password)
    else:
        return final_password


def main(length, passprint, number_of_passwords):
    if number_of_passwords:
        for i in range(number_of_passwords):
            print(generate_password(length, passprint))
    else:
        return generate_password(length, passprint)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generates secure passwords")
    parser.add_argument("-l", "--password-length", type=int, help="Password length")
    parser.add_argument(
        "-P",
        "--print-password",
        action="store_true",
        default=False,
        required=False,
        help="Password length",
    )
    parser.add_argument("-n", "--number-of-passwords", type=int, required=False)
    args = parser.parse_args()

    if not isinstance(args.password_length, int):
        sys.exit(2)

    main(args.password_length, args.print_password, args.number_of_passwords)
