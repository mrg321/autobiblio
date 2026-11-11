#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""Command-line entry point for decrypting Readium LCP books."""

import argparse
import getpass
import os
import sys

# Support running this file directly from the source checkout.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lcpdedrm


DEFAULT_LCPFILE = "futuro-a-la-vista.lcpl"


class _TemporaryFile:
    def __init__(self, extension, output_name):
        self.name = output_name + extension


class _OutputTarget:
    def __init__(self, output_name):
        self.name = output_name

    def temporary_file(self, extension):
        return _TemporaryFile(extension, self.name)


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="lcpdedrm",
        description="Decrypt a Readium LCP-encrypted ebook or audiobook.",
    )
    parser.add_argument(
        "arguments",
        nargs="*",
        metavar="ARG",
        help="passphrase and outputname, or lcpfile, passphrase, and outputname",
    )
    args = parser.parse_args(argv)

    if not args.arguments:
        lcpfile = DEFAULT_LCPFILE
        passphrase = getpass.getpass("LCP passphrase: ")
        outputname = os.path.splitext(os.path.basename(lcpfile))[0]
    elif len(args.arguments) == 2:
        lcpfile = DEFAULT_LCPFILE
        passphrase, outputname = args.arguments
    elif len(args.arguments) == 3:
        lcpfile, passphrase, outputname = args.arguments
    else:
        parser.error("provide passphrase and outputname, with optional lcpfile")

    output_name = os.path.abspath(outputname)
    result = lcpdedrm.decryptLCPbook(
        lcpfile,
        [passphrase],
        _OutputTarget(output_name),
    )
    return 0 if result is not None else 1


if __name__ == "__main__":
    raise SystemExit(main())
