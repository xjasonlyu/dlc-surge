# Domain-list-community for Surge

This project downloads latest release from v2ray dlc, to be used as Ruleset rules for Surge.

## Purpose of this project

This project contains only lists of domains. It is not opinionated, such as a domain should be blocked, or a domain should be proxied. This list can be used to generate routing rules on demand.

## Usage

- add rules to your surge conf, e.g.

```
RULE-SET,https://raw.githubusercontent.com/xjasonlyu/dlc-surge/master/data/cn,DIRECT
RULE-SET,https://raw.githubusercontent.com/xjasonlyu/dlc-surge/master/data/apple,DIRECT
```

## How it works

- This project will be updated automatically by scripts.

## Snell Bash Script
- Add snell.sh script to install/uninstall/update Snell for Surge (Debian based only for now).
```
Usage:
./snell.sh --help
```
