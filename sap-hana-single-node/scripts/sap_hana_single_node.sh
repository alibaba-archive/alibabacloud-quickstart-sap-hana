#!/bin/bash
######################################################################
# sap_hana_single_node.sh
# This script will help to setup cloud infrastructure and install HANA software
# Author: Alibaba Cloud, SAP Product & Solution Team
#####################################################################
#==================================================================
# Environments
QUICKSTART_SAP_MOUDLE='sap-hana-single-node'
QUICKSTART_SAP_MOUDLE_VERSION='1.0.3'
QUICKSTART_ROOT_DIR=$(cd $(dirname "$0" ) && pwd )
QUICKSTART_SAP_SCRIPT_DIR="${QUICKSTART_ROOT_DIR}"
QUICKSTART_FUNCTIONS_SCRIPT_PATH="${QUICKSTART_SAP_SCRIPT_DIR}/functions.sh"
QUICKSTART_LATEST_STEP=6

INFO=`cat <<EOF
    Please input Step number
    Index | Action             | Description
    -----------------------------------------------
    1     | auto install       | Automatic setup cloud infrastructure and HANA software 
    2     | manull install     | Setup cloud infrastructure and install HANA software step by step
    3     | Exit               |
EOF
`
STEP_INFO=`cat <<EOF
    Please input Step number
    Index | Action                 | Description
-----------------------------------------------
    1     | add_host           | Add hostname into hosts file
    2     | mkdisk             | Create swap,physical volumes,volume groups,logical volumes,file systems
    3     | download media     | Download HANA software
    4     | extraction media   | Extraction HANA software
    5     | install HANA       | Install HANA software 
    6     | install packages   | Install additional packages and metrics collector
    7     | Exit               |
EOF
`
PARAMS=(
    HANASID
    HANAInstanceNumber
    DataSize
    LogSize
    SharedSize
    UsrsapSize
    DiskIdsStriping
    DiskIdShared
    DiskIdUsrSap
    MediaPath
    HANASapSidAdmUid
    HANASapSysGid
    SystemUsage
    AutomationBucketName
    S4Hostname
    S4PrivateIpAddress
    FQDN
)

#==================================================================
#==================================================================
# Functions
#Define check_params function
#check_params
function check_params(){
    check_para MasterPass ${RE_PASSWORD}
    check_para HANASID ${RE_SID}
    check_para HANAInstanceNumber ${RE_INSTANCE_NUMBER}
    check_para DataSize ${RE_DISK}
    check_para LogSize ${RE_DISK}
    check_para SharedSize ${RE_DISK}
    check_para UsrsapSize ${RE_DISK}
    check_para MediaPath "^(oss|http|https)://[\\S\\w]+([\\S\\w])+$"
    check_para HANASapSidAdmUid "(^[5-9]\\d{2}$)|(^[1-9]\\d{3}$)|(^[1-5]\\d{4}$)|(^6[0-5][0-5][0-3][0-2]$)"
    check_para HANASapSysGid "^\\d+$"
    check_para SystemUsage "test|custom|development|production"
}

#Define init_variable function
#init_variable 
function init_variable(){
    echo "" > /dev/null
}

#Define add_host function
#add_host
function add_host() {
    info_log "Start to add host file"
    config_host "${ECSIpAddress} ${ECSHostname}"

    if [ -n "${S4Hostname}" ] && [ -n "${S4PrivateIpAddress}" ] && [ -n "${FQDN}" ]; then
        config_host "${S4PrivateIpAddress} ${S4Hostname} ${FQDN}"
    fi
}

#Define mkdisk function
#mkdisk DataSize LogSize SharedSize UsrsapSize 
function mkdisk() {
    info_log "Start to create swap,physical volumes,volume group,logical volumes,file systems"

    check_disks $DiskIdUsrSap $DiskIdShared $DiskIdsStriping || return 1

    disk_id_usr_sap="/dev/${DiskIdUsrSap}"
    disk_size_usr_sap="${UsrsapSize}"
    striping_disks=""
    disk_size_data="${DataSize}"
    disk_size_log="${LogSize}"
    disk_size_shared="${SharedSize}"
    disk_id_shared="/dev/${DiskIdShared}"

    for disk_id in ${DiskIdsStriping}
    do
        striping_disks="${striping_disks} /dev/${disk_id}"
    done

    pvcreate "${disk_id_usr_sap}" && vgcreate sapvg "${disk_id_usr_sap}"
    create_lv "${disk_size_usr_sap}" usrsaplv sapvg free || return 1

    pvcreate ${striping_disks} && vgcreate hanavg ${striping_disks}
    create_lv "${disk_size_data}" datalv hanavg no_free 2 || return 1
    create_lv "${disk_size_log}" loglv hanavg free 2 || return 1

    pvcreate "${disk_id_shared}" && vgcreate sharedvg "${disk_id_shared}"
    create_lv "${disk_size_shared}" sharedlv sharedvg free || return 1

    mkdir -p /usr/sap
    mkdir -p /hana/data /hana/shared /hana/log && chmod -R 755 /hana

    mkfs.xfs -f /dev/hanavg/datalv 
    mkfs.xfs -f /dev/hanavg/loglv 
    mkfs.xfs -f /dev/sharedvg/sharedlv
    mkfs.xfs -f /dev/sapvg/usrsaplv

    $(grep -q "/dev/sapvg/usrsaplv" /etc/fstab) || echo '/dev/sapvg/usrsaplv  /usr/sap  xfs defaults  0  0' >> /etc/fstab
    $(grep -q "/dev/hanavg/datalv " /etc/fstab) || echo '/dev/hanavg/datalv   /hana/data  xfs defaults  0  0' >> /etc/fstab
    $(grep -q "/dev/hanavg/loglv" /etc/fstab) || echo '/dev/hanavg/loglv /hana/log  xfs defaults  0  0' >> /etc/fstab
    $(grep -q "/dev/sharedvg/sharedlv" /etc/fstab) || echo '/dev/sharedvg/sharedlv  /hana/shared  xfs defaults  0  0' >> /etc/fstab

    mount -a || return 1
    check_filesystem "/hana/data" "/hana/log" "/hana/shared" "/usr/sap" || return 1
    info_log "Physical volumes,volume group,logical volumes,file systems have been created successful"
}

#Define check_extraction function
#check_extraction
function check_extraction {
    info_log "Start to check extraction" 
    hdblcm_path=$(find $QUICKSTART_SAP_EXTRACTION_DIR -regex .*LCM_LINUX_X86_64.*\hdblcm)
    if [ -z "${hdblcm_path}" ];then
        hdblcm_path=$(find $QUICKSTART_SAP_EXTRACTION_DIR -regex .*SERVER_LINUX_X86_64.*\hdblcm);
    fi
    if [ -z "${hdblcm_path}" ];then
        hdblcm_path=$(find $QUICKSTART_SAP_EXTRACTION_DIR -regex .*SAP_HANA_DATABASE.*\hdblcm);
    fi
    if [ -z "${hdblcm_path}" ];then
        error_log "Couldn't find 'hdblcm',please check the extracted HANA software"
        return 1
    fi
    info_log "HANA software have been extracted successful,ready to install" 
}

#Define install_client function
#install_client
function install_client(){ 
    info_log "Start to install HANA client"
    hana_sid="${HANASID}"
    hdbinst_path=$(find $QUICKSTART_SAP_EXTRACTION_DIR -regex .*SAP_HANA_CLIENT.*\hdbinst)

    if [ -z "${hdbinst_path}" ];then
        error_log "Couldn't find 'hdbinst' in $QUICKSTART_SAP_EXTRACTION_DIR/*"
        return 1
    fi
    ${hdbinst_path} --batch -sid="${hana_sid}"
}

#Define install_server function
#install_server
function install_server(){ 
    info_log "Start to install HANA server"
    login_password="${LoginPassword}"
    master_pass="${MasterPass}"
    hana_sid="${HANASID}"
    ecs_hostname="${ECSHostname}"
    instance_number="${HANAInstanceNumber}"
    hana_sap_sid_adm_uid="${HANASapSidAdmUid}"
    hana_sap_sys_gid="${HANASapSysGid}"
    system_usage="${SystemUsage}"

    hdblcm_path=$(find $QUICKSTART_SAP_EXTRACTION_DIR -regex .*SAP_HANA_DATABASE.*\hdblcm)
    if [ -z "${hdblcm_path}" ];then
        error_log "Couldn't find 'hdblcm' in $QUICKSTART_SAP_EXTRACTION_DIR/*"
        return 1
    fi
    echo '<?xml version="1.0" encoding="UTF-8"?><Passwords>
    <password><![CDATA['${master_pass}']]></password>
    <sapadm_password><![CDATA['${master_pass}']]></sapadm_password>
    <system_user_password><![CDATA['${master_pass}']]></system_user_password>
    <root_password><![CDATA['${login_password}']]></root_password>
    </Passwords>' | ${hdblcm_path} --action=install --components=server --batch --autostart=1 -sid="${hana_sid}"  --hostname="${ecs_hostname}" --number="${instance_number}" --userid="${hana_sap_sid_adm_uid}" --groupid="${hana_sap_sys_gid}" --system_usage="${system_usage}" --read_password_from_stdin=xml  >/dev/null || return 1
}

#Define install_HANA function
#install_HANA
function install_HANA(){ 
    info_log "Start to install HANA instance"
    login_password="${LoginPassword}"
    master_pass="${MasterPass}"
    hana_sid="${HANASID}"
    ecs_hostname="${ECSHostname}"
    instance_number="${HANAInstanceNumber}"
    hana_sap_sid_adm_uid="${HANASapSidAdmUid}"
    hana_sap_sys_gid="${HANASapSysGid}"
    system_usage="${SystemUsage}"

    hdblcm_path=$(find $QUICKSTART_SAP_EXTRACTION_DIR -regex .*LCM_LINUX_X86_64.*\hdblcm)
    if [ -z "${hdblcm_path}" ];then
        hdblcm_path=$(find $QUICKSTART_SAP_EXTRACTION_DIR -regex .*SERVER_LINUX_X86_64.*\hdblcm);
    fi
    if [ -z "${hdblcm_path}" ];then
        error_log "Couldn't find 'hdblcm' in $QUICKSTART_SAP_EXTRACTION_DIR/*"
        return 1
    fi
    echo '<?xml version="1.0" encoding="UTF-8"?><Passwords>
    <password><![CDATA['${master_pass}']]></password>
    <sapadm_password><![CDATA['${master_pass}']]></sapadm_password>
    <system_user_password><![CDATA['${master_pass}']]></system_user_password>
    <root_password><![CDATA['${login_password}']]></root_password>
    </Passwords>' | ${hdblcm_path} --action=install --components=client,server --batch --autostart=1 -sid="${hana_sid}"  --hostname="${ecs_hostname}" --number="${instance_number}" --userid="${hana_sap_sid_adm_uid}" --groupid="${hana_sap_sys_gid}" --system_usage="${system_usage}" --read_password_from_stdin=xml  >/dev/null || return 1
}

# Define setup function
# run step
function run(){
    case "$1" in
        1)
            add_host
            ;;
        2)
            mkdisk || return 1
            ;;
        3)
            mkdir -p "${QUICKSTART_SAP_DOWNLOAD_DIR}"
            download_medias "${MediaPath}" || return 1
            ;;
        4)
            if ls "${QUICKSTART_SAP_DOWNLOAD_DIR}" | grep -qE "^IMDB_SERVE.*SAR$"
            then
                server_path=$(ls ${QUICKSTART_SAP_DOWNLOAD_DIR} | grep -E "^IMDB_SERVER.*SAR$")
                sar_extraction "${QUICKSTART_SAP_DOWNLOAD_DIR}/${server_path}" "${QUICKSTART_SAP_EXTRACTION_DIR}" "manifest" || return 1
                if ls "${QUICKSTART_SAP_DOWNLOAD_DIR}" | grep -qE "^IMDB_CLIENT.*SAR$"
                then
                    client_path=$(ls ${QUICKSTART_SAP_DOWNLOAD_DIR} | grep -E "^IMDB_CLIENT.*SAR$")
                    sar_extraction "${QUICKSTART_SAP_DOWNLOAD_DIR}/${client_path}" "${QUICKSTART_SAP_EXTRACTION_DIR}" || return 1
                fi
            else
                auto_extraction "${QUICKSTART_SAP_DOWNLOAD_DIR}"
                chmod -R 777 "${QUICKSTART_SAP_DOWNLOAD_DIR}"/*
            fi
            check_extraction || return 1
            ;;
        5)
            if ls "${QUICKSTART_SAP_EXTRACTION_DIR}" | grep -qE "^SAP_HANA_DATABASE$"
            then
                install_server || return 1
                if ls "${QUICKSTART_SAP_EXTRACTION_DIR}" | grep -qE "^SAP_HANA_CLIENT$"
                then
                    install_client || warning_log "Filed to install HANA client."
                fi
            else
                install_HANA || return 1
            fi
            validation_hana "${HANASID}" "${HANAInstanceNumber}" || return 1
            ;;
        6)
            single_node_packages
            if [[ -n "${S4Hostname}" ]];then
                APP_post
            else
                HANA_post
            fi
            ;;
        *)
            error_log "Can't match Mark value,please check whether modified the Mark file"
            exit 1
            ;;
    esac
}

#==================================================================
#==================================================================
#Implementation
if [[ -s "${QUICKSTART_FUNCTIONS_SCRIPT_PATH}" ]]
then
    source "${QUICKSTART_FUNCTIONS_SCRIPT_PATH}"
    if [[ $? -ne 0 ]]
    then
        echo "Import file(${QUICKSTART_FUNCTIONS_SCRIPT_PATH}) error!"
    fi
else
    echo "Missing required file ${QUICKSTART_FUNCTIONS_SCRIPT_PATH}!"
    exit 1
fi

install $@ || EXIT
