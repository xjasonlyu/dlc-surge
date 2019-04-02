#!/bin/bash
# Modified from 'V2Ray' <https://install.direct/go.sh>

CUR_VER=""
NEW_VER=""
ARCH=""
CONFIG="/etc/snell/snell-server.conf"
BINROOT="/usr/local/bin"
TMPROOT="/tmp/snell"
ZIPFILE="/tmp/snell/snell-server.zip"

CMD_INSTALL=""
CMD_UPDATE=""

SNELL_RUNNING=0
SOFTWARE_UPDATED=0

SYSTEMCTL_CMD=$(command -v systemctl 2>/dev/null)
SERVICE_CMD=$(command -v service 2>/dev/null)

#######color code########
RED="31m"      # Error message
GREEN="32m"    # Success message
YELLOW="33m"   # Warning message
BLUE="36m"     # Info message

colorEcho(){
    COLOR=$1
    echo -e "\033[${COLOR}${@:2}\033[0m"
}

sysArch() {
    UNAME=$(uname -m)
    if [[ "$UNAME" == "i686" ]] || [[ "$UNAME" == "i386" ]]; then
        ARCH="i386"
    else
        ARCH="amd64"
    fi
    return 0
}

downloadSnell() {
    rm -rf ${TMPROOT}
    mkdir -p ${TMPROOT}
    DOWNLOAD_LINK="https://github.com/surge-networks/snell/releases/download/${NEW_VER}/snell-server-${NEW_VER}-linux-${ARCH}.zip"
    colorEcho ${BLUE} "Downloading Snell: ${DOWNLOAD_LINK}"
    curl -L -H "Cache-Control: no-cache" -o ${ZIPFILE} ${DOWNLOAD_LINK}
    if [ $? != 0 ];then
        colorEcho ${RED} "Failed to download! Please check your network or try again."
        return 3
    fi
    return 0
}

getVersion() {
    VER=`/usr/local/bin/snell-server -v 2>&1`
    RETVAL="$?"
    CUR_VER=`echo $VER | head -n 1 | cut -d " " -f6`
    if [[ ${CUR_VER} != v* ]]; then
        CUR_VER=v${CUR_VER}
    fi
    TAG_URL="https://api.github.com/repos/surge-networks/snell/releases/latest"
    NEW_VER=`curl -s ${TAG_URL} --connect-timeout 10| grep 'tag_name' | cut -d\" -f4`
    if [[ ${NEW_VER} != v* ]]; then
        NEW_VER=v${NEW_VER}
    fi
    if [[ $? -ne 0 ]] || [[ $NEW_VER == "" ]]; then
        colorEcho ${RED} "Failed to fetch release information. Please check your network or try again."
        return 3
    elif [[ $RETVAL -ne 0 ]];then
        return 2
    elif [[ $NEW_VER != $CUR_VER ]];then
        return 1
    fi
    return 0
}

extract(){
    colorEcho ${BLUE} "Extracting Snell package to ${TMPROOT}."
    mkdir -p ${TMPROOT}
    unzip $1 -d ${TMPROOT}
    if [[ $? -ne 0 ]]; then
        colorEcho ${RED} "Failed to extract Snell."
        return 2
    fi
    return 0
}

stopSnell(){
    colorEcho ${BLUE} "Shutting down Snell service."
    if [[ -n "${SYSTEMCTL_CMD}" ]] || [[ -f "/lib/systemd/system/snell.service" ]] || [[ -f "/etc/systemd/system/snell.service" ]]; then
        ${SYSTEMCTL_CMD} stop snell
    elif [[ -n "${SERVICE_CMD}" ]] || [[ -f "/etc/init.d/snell" ]]; then
        ${SERVICE_CMD} snell stop
    fi
    if [[ $? -ne 0 ]]; then
        colorEcho ${YELLOW} "Failed to shutdown Snell service."
        return 2
    fi
    return 0
}

startSnell(){
    if [ -n "${SYSTEMCTL_CMD}" ] && [ -f "/lib/systemd/system/snell.service" ]; then
        ${SYSTEMCTL_CMD} start snell
    elif [ -n "${SYSTEMCTL_CMD}" ] && [ -f "/etc/systemd/system/snell.service" ]; then
        ${SYSTEMCTL_CMD} start snell
    elif [ -n "${SERVICE_CMD}" ] && [ -f "/etc/init.d/snell" ]; then
        ${SERVICE_CMD} snell start
    fi
    if [[ $? -ne 0 ]]; then
        colorEcho ${YELLOW} "Failed to start Snell service."
        return 2
    fi
    return 0
}

copyFile() {
    NAME=$1
    ERROR=`cp "${TMPROOT}/${NAME}" "${BINROOT}/${NAME}" 2>&1`
    if [[ $? -ne 0 ]]; then
        colorEcho ${YELLOW} "${ERROR}"
        return 1
    fi
    return 0
}

makeExecutable() {
    chmod +x "${BINROOT}/$1"
}

installSnell(){
    copyFile snell-server
    if [[ $? -ne 0 ]]; then
        colorEcho ${RED} "Failed to copy snell-server binary."
        return 1
    fi
    makeExecutable snell-server

    # Install Snell server config to /etc/snell
    if [[ ! -f $CONFIG ]]; then
        mkdir -p /etc/snell
        mkdir -p /var/log/snell
        
        let PORT=$RANDOM+10000
        PSK=$(LC_ALL=C tr -dc A-Za-z0-9 < /dev/urandom | head -c 32)

        cat > $CONFIG <<EOF
[snell-server]
listen = 0.0.0.0:${PORT}
psk = ${PSK}
# obfs = http
EOF
        colorEcho ${BLUE} "PORT:${PORT}"
        colorEcho ${BLUE} "PSK:${PSK}"
    fi
    return 0
}

installInitScript(){
    if [[ -n "${SYSTEMCTL_CMD}" ]];then
        if [[ ! -f "/etc/systemd/system/snell.service" ]]; then
            if [[ ! -f "/lib/systemd/system/snell.service" ]]; then
                cat > ${TMPROOT}/snell.service <<EOF
[Unit]
Description=Snell Proxy Service
After=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
LimitNOFILE=32768
ExecStart=/usr/local/bin/snell-server -c /etc/snell/snell-server.conf

[Install]
WantedBy=multi-user.target
EOF
                cp "${TMPROOT}/snell.service" "/etc/systemd/system/"
                systemctl enable snell.service
            fi
        fi
        return
    elif [[ -n "${SERVICE_CMD}" ]] && [[ ! -f "/etc/init.d/snell" ]]; then
        # TODO: Add SERVICE Support
        colorEcho ${RED} "Didn't support service yet."
        return 1
    fi
    return 0
}

installSoftware(){
    COMPONENT=$1
    if [[ -n `command -v $COMPONENT` ]]; then
        return 0
    fi

    getPMT
    if [[ $? -eq 1 ]]; then
        colorEcho ${RED} "The system package manager tool isn't APT or YUM, please install ${COMPONENT} manually."
        return 1 
    fi
    if [[ $SOFTWARE_UPDATED -eq 0 ]]; then
        colorEcho ${BLUE} "Updating software repo"
        $CMD_UPDATE      
        SOFTWARE_UPDATED=1
    fi

    colorEcho ${BLUE} "Installing ${COMPONENT}"
    $CMD_INSTALL $COMPONENT
    if [[ $? -ne 0 ]]; then
        colorEcho ${RED} "Failed to install ${COMPONENT}. Please install it manually."
        return 1
    fi
    return 0
}

# return 1: not apt, yum, or zypper
getPMT(){
    if [[ -n `command -v apt-get` ]];then
        CMD_INSTALL="apt-get -y -qq install"
        CMD_UPDATE="apt-get -qq update"
    elif [[ -n `command -v yum` ]]; then
        CMD_INSTALL="yum -y -q install"
        CMD_UPDATE="yum -q makecache"
    elif [[ -n `command -v zypper` ]]; then
        CMD_INSTALL="zypper -y install"
        CMD_UPDATE="zypper ref"
    else
        return 1
    fi
    return 0
}

remove(){
    if [[ -n "${SYSTEMCTL_CMD}" ]] && [[ -f "/etc/systemd/system/snell.service" ]];then
        if pgrep "snell-server" > /dev/null ; then
            stopSnell
        fi
        systemctl disable snell.service
        rm -rf "/usr/local/bin/snell-server" "/etc/systemd/system/snell.service"
        if [[ $? -ne 0 ]]; then
            colorEcho ${RED} "Failed to remove snell."
            return 0
        else
            colorEcho ${GREEN} "Removed snell successfully."
            colorEcho ${BLUE} "If necessary, please remove configuration file and log file manually."
            return 0
        fi
    elif [[ -n "${SYSTEMCTL_CMD}" ]] && [[ -f "/lib/systemd/system/snell.service" ]];then
        if pgrep "snell-server" > /dev/null ; then
            stopSnell
        fi
        systemctl disable snell.service
        rm -rf "/usr/local/bin/snell" "/lib/systemd/system/snell.service"
        if [[ $? -ne 0 ]]; then
            colorEcho ${RED} "Failed to remove snell."
            return 0
        else
            colorEcho ${GREEN} "Removed snell successfully."
            colorEcho ${BLUE} "If necessary, please remove configuration file and log file manually."
            return 0
        fi
    elif [[ -n "${SERVICE_CMD}" ]] && [[ -f "/etc/init.d/snell" ]]; then
        if pgrep "snell-server" > /dev/null ; then
            stopSnell
        fi
        rm -rf "/usr/local/bin/snell" "/etc/init.d/snell"
        if [[ $? -ne 0 ]]; then
            colorEcho ${RED} "Failed to remove snell."
            return 0
        else
            colorEcho ${GREEN} "Removed snell successfully."
            colorEcho ${BLUE} "If necessary, please remove configuration file and log file manually."
            return 0
        fi       
    else
        colorEcho ${YELLOW} "snell not found."
        return 0
    fi
}

Help(){
    echo "./snell.sh [-h] [--remove]"
    echo "  -h, --help            Show help"
    echo "      --remove          Remove installed V2Ray"
    return 0
}


main() {
    #helping information
    [[ "$HELP" == "1" ]] && Help && return
    [[ "$REMOVE" == "1" ]] && remove && return

    sysArch
    # download via network and extract
    installSoftware "curl" || return $?
    getVersion
    RETVAL="$?"
    if [[ $RETVAL == 0 ]]; then
        colorEcho ${BLUE} "Latest version ${NEW_VER} is already installed."
        return 0
    elif [[ $RETVAL == 3 ]]; then
        return 3
    else
        colorEcho ${BLUE} "Installing Snell ${NEW_VER}"
        downloadSnell || return $?
        installSoftware unzip || return $?
        extract ${ZIPFILE} || return $?
    fi

    if pgrep "snell-server" > /dev/null ; then
        SNELL_RUNNING=1
        stopSnell
    fi
    installSnell || return $?
    installInitScript || return $?
    if [[ ${SNELL_RUNNING} -eq 1 ]];then
        colorEcho ${BLUE} "Restarting Snell service."
        startSnell
    fi
    colorEcho ${GREEN} "Snell ${NEW_VER} is installed."
    rm -rf ${TMPROOT}
    return 0
}

#########################
while [[ $# > 0 ]];do
    key="$1"
    case $key in
        -h|--help)
        HELP="1"
        ;;
        --remove)
        REMOVE="1"
        ;;
        *)
                # unknown option
        ;;
    esac
    shift # past argument or value
done

main
