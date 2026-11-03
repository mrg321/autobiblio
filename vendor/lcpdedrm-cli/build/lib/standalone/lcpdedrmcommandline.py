#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""Command-line entry point for decrypting Readium LCP books."""

import argparse
import os

import lcpdedrm


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
        description="Decrypt a Readium LCP-encrypted ebook.",
    )
    parser.add_argument("lcpfile", help="path to the LCP-encrypted ebook")
    parser.add_argument("passphrase", help="LCP passphrase")
    parser.add_argument(
        "outputname",
        help="output path without an extension; the correct extension is added",
    )
    args = parser.parse_args(argv)

    output_name = os.path.abspath(args.outputname)
    result = lcpdedrm.decryptLCPbook(
        args.lcpfile,
        [args.passphrase],
        _OutputTarget(output_name),
    )
    return 0 if result is not None else 1


if __name__ == "__main__":
    raise SystemExit(main())
