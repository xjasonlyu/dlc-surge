#!/bin/bash
# written by xjasonlyu

cd `dirname $0`

NEW_VER=""
CUR_VER=""
TMP_DIR="/tmp/dlc"
DLC_DIR="data"
VER_FILE="version"
DATA_DIR=""
REPO_URL="https://github.com/xjasonlyu/dlc-surge.git"
PYTHON3=`which python3`

getVersion()
{
    TAG_URL="https://api.github.com/repos/v2ray/domain-list-community/releases/latest"
    NEW_VER=`curl -s ${TAG_URL} --connect-timeout 10| grep 'tag_name' | cut -d\" -f4`
    if [[ -f ${VER_FILE} ]]; then
        CUR_VER=`cat ${VER_FILE}`
    fi
}

downloadDlc()
{
    # delete old files
    if [[ ! -d ${TMP_DIR} ]]; then
        mkdir -p ${TMP_DIR}
    else
        rm -rf ${TMP_DIR}/*
    fi
    # downloading...
    DATA_DIR="${TMP_DIR}/domain-list-community-${NEW_VER}/data"
    curl -s -L -H "Cache-Control: no-cache" -o ${TMP_DIR}/${NEW_VER}.zip "https://github.com/v2ray/domain-list-community/archive/${NEW_VER}.zip"
    unzip -q ${TMP_DIR}/${NEW_VER}.zip -d ${TMP_DIR}
    if [[ ! -d ${DATA_DIR} ]]; then
        echo "data folder missing"
        exit 1
    fi
}

generateData()
{
    # Create data folder
    mkdir -p ${DLC_DIR}
    # generate domain-list to files
    for i in `ls ${DATA_DIR}`; do
        ${PYTHON3} ./convert.py ${DATA_DIR}/${i} | tee ${DLC_DIR}/${i} > /dev/null
    done

    # alias geolocatin-!cn -> !cn
    [ -f "${DLC_DIR}/geolocation-!cn" ] && cat "${DLC_DIR}/geolocation-!cn" | tee "${DLC_DIR}/!cn" > /dev/null
}

gitUpload()
{
    if [[ ! -d .git ]]; then
        git init
    fi
    # Refresh local copy
    git pull origin master
    # Add .gitignore
    if [[ -f .gitignore ]]; then
        git add .gitignore
    fi
    # add files to git
    for i in `ls .`; do
        git add ${i}
    done
    # commit
    git commit -m "v${NEW_VER}"
    # push
    git remote add origin ${REPO_URL}
    git remote -v
    git push -u origin master
    # complete
    echo "Done!"
}

main()
{
    getVersion
    if [[ ${CUR_VER} == ${NEW_VER} ]] && [[ -d ${DLC_DIR} ]]; then
        echo "v${CUR_VER} is the latest version"
    else
        echo "found new version v${NEW_VER}"
        #
        downloadDlc
        #
        generateData
        # remove tmp files
        rm -rf ${TMP_DIR}
    fi

    echo "${NEW_VER}" | tee ${VER_FILE} > /dev/null

    # upload to Github
    gitUpload
}

main
