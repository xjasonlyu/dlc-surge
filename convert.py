#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# written by xjasonlyu
#

import os
import sys


def convert(data: str) -> str:
    if not data.strip():
        return ""
    elif data.startswith("#"):
        return data
    # Structure of data
    data = data.strip().split(maxsplit=1)[0]
    if data.startswith("keyword:"):
        return "DOMAIN-KEYWORD," + data[8:] + '\n'
    elif data.startswith("full:"):
        return "DOMAIN," + data[5:] + '\n'
    elif data.startswith("regex:"):
        print("Warning: ignore {!s}".format(data), file=sys.stderr)
        return ""
    elif data.startswith("include:"):
        extra = ""
        with open(data[8:]) as f:
            for line in f:
                extra += convert(line)
        return extra
    elif data.startswith("domain:"):
        return "DOMAIN-SUFFIX," + data[7:] + '\n'
    else:
        return "DOMAIN-SUFFIX," + data + '\n'


def main():
    if len(sys.argv) != 2:
        print("Usage: {!s} /path/to/domain-list".format(os.path.basename(sys.argv[0])), file=sys.stderr)
        sys.exit(1)
    elif not os.path.exists(sys.argv[1]):
        print("File {!s} doesn't exists".format(sys.argv[1]), file=sys.stderr)
        sys.exit(1)

    # cd `dirname <file>`
    d = os.path.dirname(sys.argv[1])
    os.chdir(d)
    with open(os.path.basename(sys.argv[1])) as f:
        for line in f:
            print(convert(line), end='', flush=True)


if __name__ == "__main__":
    main()
