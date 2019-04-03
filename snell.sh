#!/bin/bash
# Modified from 'V2Ray' <https://install.direct/go.sh>

# If not specify, default meaning of return value:
# 0: Success
# 1: System error
# 2: Application error
# 3: Network error

CUR_VER=""
NEW_VER=""
ARCH=""
CONFIG="/etc/snell/snell-server.conf"
BINROOT="/usr/local/bin"
SNELL_BIN="${BINROOT}/snell-server"
TMPROOT="/tmp/snell"
ZIPFILE="/tmp/snell/snell-server.zip"

CMD_INSTALL=""
CMD_UPDATE=""

SNELL_RUNNING=0
SOFTWARE_UPDATED=0

SYSTEMCTL_CMD=$(command -v systemctl 2>/dev/null)
SERVICE_CMD=$(command -v service 2>/dev/null)

CHECK=""
FORCE=""
HELP=""
VERSION=""

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
    elif [[ "$UNAME" == *"armv7"* ]] || [[ "$UNAME" == "armv6l" ]]; then
        ARCH="armv7l"
    elif [[ "$UNAME" == *"armv8"* ]] || [[ "$UNAME" == "aarch64" ]]; then
        return 1
    elif [[ "$UNAME" == *"s390x"* ]] || [[ "$UNAME" == *"ppc"* ]]; then
        return 2
    elif [[ "$UNAME" == *"mips"* ]]; then
        return 3
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
    curl ${PROXY} -L -H "Cache-Control: no-cache" -o ${ZIPFILE} ${DOWNLOAD_LINK}
    if [ $? != 0 ];then
        colorEcho ${RED} "Failed to download! Please check your network or try again."
        return 3
    fi
    return 0
}

# 1: new Snell. 0: no. 2: not installed. 3: check failed. 4: don't check.
getVersion() {
    # If VERSION is specified
    if [[ -n "$VERSION" ]]; then
        NEW_VER="$VERSION"
        if [[ ${NEW_VER} != v* ]]; then
          NEW_VER=v${NEW_VER}
        fi
        return 4
    fi

    VER=`${SNELL_BIN} -v 2>&1`
    RETVAL="$?"
    CUR_VER=`echo $VER | head -n 1 | cut -d " " -f6`
    if [[ ${CUR_VER} != v* ]]; then
        CUR_VER=v${CUR_VER}
    fi
    TAG_URL="https://api.github.com/repos/surge-networks/snell/releases/latest"
    NEW_VER=`curl ${PROXY} -s ${TAG_URL} --connect-timeout 10| grep 'tag_name' | cut -d\" -f4`
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
ExecStart=${SNELL_BIN} -c ${CONFIG}

[Install]
WantedBy=multi-user.target
EOF
                cp "${TMPROOT}/snell.service" "/etc/systemd/system/"
                systemctl enable snell.service
            fi
        fi
        return
    elif [[ -n "${SERVICE_CMD}" ]] && [[ ! -f "/etc/init.d/snell" ]]; then
        installSoftware "daemon" || return $?
        cat > ${TMPROOT}/snell.init <<EOF
#!/bin/sh
### BEGIN INIT INFO
# Provides:          Snell
# Required-Start:    $network $local_fs $remote_fs
# Required-Stop:     $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: snell proxy services
# Description:       snell proxy services
### END INIT INFO

# Acknowledgements: Isulew Li <netcookies@gmail.com>

DESC=snell
NAME=snell
DAEMON=${SNELL_BIN}
PIDFILE=/var/run/$NAME.pid
SCRIPTNAME=/etc/init.d/$NAME

DAEMON_OPTS="-c ${CONFIG}"

# Exit if the package is not installed
[ -x $DAEMON ] || exit 0

# Read configuration variable file if it is present
[ -r /etc/default/$NAME ] && . /etc/default/$NAME

# Load the VERBOSE setting and other rcS variables
. /lib/init/vars.sh

# Define LSB log_* functions.
# Depend on lsb-base (>= 3.0-6) to ensure that this file is present.
. /lib/lsb/init-functions

#
# Function that starts the daemon/service
#
do_start()
{
    mkdir -p /var/log/snell
    # Return
    #   0 if daemon has been started
    #   1 if daemon was already running
    #   2 if daemon could not be started
    #   3 if configuration file not ready for daemon
    start-stop-daemon --start --quiet --pidfile $PIDFILE --exec $DAEMON --test > /dev/null \
        || return 1
    start-stop-daemon --start --quiet --pidfile $PIDFILE --exec $DAEMON --background -m -- $DAEMON_OPTS \
        || return 2
    # Add code here, if necessary, that waits for the process to be ready
    # to handle requests from services started subsequently which depend
    # on this one.  As a last resort, sleep for some time.
}

#
# Function that stops the daemon/service
#
do_stop()
{
    # Return
    #   0 if daemon has been stopped
    #   1 if daemon was already stopped
    #   2 if daemon could not be stopped
    #   other if a failure occurred
    start-stop-daemon --stop --quiet --retry=TERM/30/KILL/5 --pidfile $PIDFILE
    RETVAL="$?"
    [ "$RETVAL" = 2 ] && return 2
    # Wait for children to finish too if this is a daemon that forks
    # and if the daemon is only ever run from this initscript.
    # If the above conditions are not satisfied then add some other code
    # that waits for the process to drop all resources that could be
    # needed by services started subsequently.  A last resort is to
    # sleep for some time.
    start-stop-daemon --stop --quiet --oknodo --retry=0/30/KILL/5 --exec $DAEMON
    [ "$?" = 2 ] && return 2
    # Many daemons don't delete their pidfiles when they exit.
    rm -f $PIDFILE
    return "$RETVAL"
}

#
# Function that sends a SIGHUP to the daemon/service
#
do_reload() {
    #
    # If the daemon can reload its configuration without
    # restarting (for example, when it is sent a SIGHUP),
    # then implement that here.
    #
    start-stop-daemon --stop --signal 1 --quiet --pidfile $PIDFILE
    return 0
}

case "$1" in
  start)
    [ "$VERBOSE" != no ] && log_daemon_msg "Starting $DESC " "$NAME"
    do_start
    case "$?" in
        0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
        2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
    esac
  ;;
  stop)
    [ "$VERBOSE" != no ] && log_daemon_msg "Stopping $DESC" "$NAME"
    do_stop
    case "$?" in
        0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
        2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
    esac
    ;;
  status)
       status_of_proc "$DAEMON" "$NAME" && exit 0 || exit $?
       ;;
  reload|force-reload)
    #
    # If do_reload() is not implemented then leave this commented out
    # and leave 'force-reload' as an alias for 'restart'.
    #
    log_daemon_msg "Reloading $DESC" "$NAME"
    do_reload
    log_end_msg $?
    ;;
  restart|force-reload)
    #
    # If the "reload" option is implemented then remove the
    # 'force-reload' alias
    #
    log_daemon_msg "Restarting $DESC" "$NAME"
    do_stop
    case "$?" in
      0|1)
        do_start
        case "$?" in
            0) log_end_msg 0 ;;
            1) log_end_msg 1 ;; # Old process is still running
            *) log_end_msg 1 ;; # Failed to start
        esac
        ;;
      *)
        # Failed to stop
        log_end_msg 1
        ;;
    esac
    ;;
  *)
    #echo "Usage: $SCRIPTNAME {start|stop|restart|reload|force-reload}" >&2
    echo "Usage: $SCRIPTNAME {start|stop|status|reload|restart|force-reload}" >&2
    exit 3
    ;;
esac

EOF
        cp "${TMPROOT}/snell.init" "/etc/init.d/snell"
        chmod +x "/etc/init.d/snell"
        update-rc.d snell defaults
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
        rm -rf "${SNELL_BIN}" "/etc/systemd/system/snell.service"
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
        rm -rf "${SNELL_BIN}" "/lib/systemd/system/snell.service"
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
        rm -rf "${SNELL_BIN}" "/etc/init.d/snell"
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
    echo "./snell.sh [-h] [-c] [--remove] [-p proxy] [-f] [--version vx.y.z] [-l file] [--extractonly]"
    echo "  -h, --help            Show help"
    echo "  -p, --proxy           To download through a proxy server, use -p socks5://127.0.0.1:1080 or -p http://127.0.0.1:3128 etc"
    echo "  -f, --force           Force install"
    echo "      --version         Install a particular version, use --version v1.0.0"
    echo "  -l, --local           Install from a local file"
    echo "      --remove          Remove (uninstall) installed Snell"
    echo "      --extractonly     Extract snell but don't install"
    echo "  -c, --check           Check for update"
    return 0
}

checkUpdate(){
    echo "Checking for update."
    VERSION=""
    getVersion
    RETVAL="$?"
    if [[ $RETVAL -eq 1 ]]; then
        colorEcho ${BLUE} "Found new version ${NEW_VER} for Snell.(Current version:${CUR_VER})"
    elif [[ $RETVAL -eq 0 ]]; then
        colorEcho ${BLUE} "No new version. Current version is ${NEW_VER}."
    elif [[ $RETVAL -eq 2 ]]; then
        colorEcho ${YELLOW} "No Snell installed."
        colorEcho ${BLUE} "The newest version for Snell is ${NEW_VER}."
    fi
    return 0
}

main() {
    #helping information
    [[ "$HELP" == "1" ]] && Help && return
    [[ "$CHECK" == "1" ]] && checkUpdate && return
    [[ "$REMOVE" == "1" ]] && remove && return

    sysArch
    if [[ "$?" != 0 ]]; then
        colorEcho ${RED} "Unsupported arch ${ARCH}"
        return 1
    fi

    if [[ $LOCAL_INSTALL -eq 1 ]]; then
        colorEcho ${YELLOW} "Installing Snell via local file. Please make sure the file is a valid Snell package, as we are not able to determine that."
        NEW_VER=local
        installSoftware unzip || return $?
        rm -rf ${TMPROOT}
        extract $LOCAL || return $?
    else
        # download via network and extract
        installSoftware "curl" || return $?
        getVersion
        RETVAL="$?"
        if [[ $RETVAL == 0 ]] && [[ "$FORCE" != "1" ]]; then
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
    fi

    if [[ "${EXTRACT_ONLY}" == "1" ]]; then
        colorEcho ${GREEN} "Snell extracted to ${TMPROOT}, and exiting..."
        return 0
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
        -p|--proxy)
        PROXY="-x ${2}"
        shift # past argument
        ;;
        -h|--help)
        HELP="1"
        ;;
        -f|--force)
        FORCE="1"
        ;;
        -c|--check)
        CHECK="1"
        ;;
        --remove)
        REMOVE="1"
        ;;
        --version)
        VERSION="$2"
        shift
        ;;
        --extractonly)
        EXTRACT_ONLY="1"
        ;;
        -l|--local)
        LOCAL="$2"
        LOCAL_INSTALL="1"
        shift
        ;;
        *)
                # unknown option
        ;;
    esac
    shift # past argument or value
done

main
