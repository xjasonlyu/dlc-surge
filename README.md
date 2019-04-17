# Domain-list-community for Surge

This project downloads latest release from v2ray dlc, to be used as Ruleset rules for Surge.

## Purpose of this project

This project contains only lists of domains. It is not opinionated, such as a domain should be blocked, or a domain should be proxied. This list can be used to generate routing rules on demand.

## Usage

- add rules to your surge conf, e.g.

```
RULE-SET,https://github.com/xjasonlyu/dlc-surge/raw/master/data/cn,DIRECT
RULE-SET,https://github.com/xjasonlyu/dlc-surge/raw/master/data/google,PROXY
```

## How it works

- This project will be updated automatically by scripts.

# Snell Bash Script (Modified from V2Ray Official Script)
- Use snell.sh script to install/uninstall/update snell-server for Surge (linux only).
- Install Snell
```
bash <(curl -L -s https://raw.githubusercontent.com/xjasonlyu/dlc-surge/master/snell.sh)
```
- Usage
```
./snell.sh [-h] [-c] [--remove] [-p proxy] [-f] [--version vx.y.z] [-l file] [--extractonly]
  -h, --help            Show help
  -p, --proxy           To download through a proxy server, use -p socks5://127.0.0.1:1080 or -p http://127.0.0.1:3128 etc
  -f, --force           Force install
      --version         Install a particular version, use --version v1.0.0
  -l, --local           Install from a local file
      --remove          Remove (uninstall) installed Snell
      --extractonly     Extract snell but don't install
  -c, --check           Check for update
```
