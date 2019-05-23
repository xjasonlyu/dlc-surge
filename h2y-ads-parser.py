#!/usr/bin/env python3
import re
import requests
from io import StringIO

ads_rule = "https://raw.githubusercontent.com/h2y/Shadowrocket-ADBlock-Rules/master/sr_direct_banad.conf"


def http_get(url):
    r = requests.get(url)
    if r.status_code != 200:
        raise Exception("requests status != 200")
    return r.text


def main():
    rule = http_get(ads_rule)
    reg = re.compile(r".+,.+,Reject")
    rule_lines = StringIO(rule)
    for line in rule_lines:
        result = re.findall(reg, line)
        if len(result) != 1:
            continue
        print(result[0][:-7])


if __name__ == "__main__":
    main()

