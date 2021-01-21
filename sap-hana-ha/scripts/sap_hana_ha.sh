#!/bin/bash
#################################################################################################################
# sap_hana_ha.sh
# The script will setup cloud infrastructure and configure HANA system replication, high availability
# Author: Alibaba Cloud, SAP Product & Solution Team
#################################################################################################################
#================================================================================================================
# Environments
QUICKSTART_SAP_MOUDLE='sap-hana-ha'
QUICKSTART_SAP_MOUDLE_VERSION='1.0.3'
QUICKSTART_ROOT_DIR=$(cd $(dirname "$0" ) && pwd )
QUICKSTART_SAP_SCRIPT_DIR="${QUICKSTART_ROOT_DIR}"
QUICKSTART_FUNCTIONS_SCRIPT_PATH="${QUICKSTART_SAP_SCRIPT_DIR}/functions.sh"
QUICKSTART_LATEST_STEP=11

INFO=`cat <<EOF
    Please input Step number
    Index | Action                  | Description
    -----------------------------------------------
    1     | auto install            | Automatic setup cloud infrastructure and configure HANA system replication, high availability
    2     | manual install          | Setup cloud infrastructure and configure HANA system replication, high availability step by step
    3     | Exit                    |
EOF
`
STEP_INFO=`cat <<EOF
    Please input Step number
    Index | Action                  | Description
    -----------------------------------------------
    1     | add host                | Add hostname into hosts file
    2     | mkdisk                  | Create swap,physical volumes,volume group,logical volumes,file systems
    3     | download media          | Download HANA software
    4     | extraction media        | Extraction HANA software
    5     | install HANA            | Install HANA software
    6     | install packages        | Install additional packages and metrics collector
    7     | config ENI              | Configure elastic network card(ENI)
    8     | config SSH              | Configure SSH
    9     | config HSR              | Configure HANA system replication(HSR)
    10    | config SBD/corosync     | Install and configure cluster SBD/corosync
    11    | config resource         | Configure cluster resource
    12    | Exit                    |
EOF
`
PARAMS=(
    HANASID
    HANAInstanceNumber
    DataSize
    LogSize
    SharedSize
    DiskIdsStriping
    DiskIdShared
    DiskIdUsrSap
    MediaPath
    HANASapSidAdmUid
    HANASapSysGid
    SystemUsage
    NodeType
    ECSHeartIpAddress
    HeartNetworkCard
    HAVIPIpAddress
    ClusterMemberIpAddress
    ClusterMemberHeartIpAddress
    ClusterMemberHostname
    HAQuorumDisk
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
    [[ -n "${HANASwapDiskSize}" ]] && check_para HANASwapDiskSize ${RE_DISK}
    check_para NodeType "Master|Slave"
    check_para ECSHeartIpAddress ${RE_IP}
    check_para HAVIPIpAddress ${RE_IP}
    check_para ClusterMemberIpAddress ${RE_IP}
    check_para ClusterMemberHeartIpAddress ${RE_IP}
    check_para ClusterMemberHostname ${RE_HOSTNAME}
    check_para HeartNetworkCard "^\S+$"
    check_para HAQuorumDisk "^vd[b-z]$"

    [[ -n "${S4Hostname}" ]] && check_para S4Hostname ${RE_HOSTNAME}
    [[ -n "${S4PrivateIpAddress}" ]] &&  check_para S4PrivateIpAddress ${RE_IP}
    [[ -n "${FQDN}" ]] &&  check_para FQDN '(?!-)[a-zA-Z0-9-.]*(?<!-)'
}

#Define init_variable function
#init_variable 
function init_variable(){
    CorosyncConfigurationTemplateURL="http://${AutomationBucketName}.oss-${QUICKSTART_SAP_REGION}.aliyuncs.com/alibabacloud-quickstart/v1/sap-hana/sap-hana-ha/scripts/corosync_configuration_template.cfg"
    CorosyncConfigurationTemplatePath="${QUICKSTART_SAP_SCRIPT_DIR}/template_corosync_configuration.cfg"
    ResourcesConfigurationTemplateURL="http://${AutomationBucketName}.oss-${QUICKSTART_SAP_REGION}.aliyuncs.com/alibabacloud-quickstart/v1/sap-hana/sap-hana-ha/scripts/sap_hana_ha_configuration_template.cfg"
    ResourcesConfigurationTemplatePath="${QUICKSTART_SAP_SCRIPT_DIR}/template_HANA_HA_configuration.cfg"
    ResourcesConfigurationFilePath="${QUICKSTART_SAP_SCRIPT_DIR}/HANA_HA_configuration_file.cfg"
    HANASidAdm="$(echo ${HANASID} |tr '[:upper:]' '[:lower:]')adm"
}

#Define add_host function
#add_host 
function add_host() {
    info_log "Start to add host file"
    config_host "${ECSIpAddress} ${ECSHostname}"
    config_host "${ClusterMemberIpAddress} ${ClusterMemberHostname}"

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
        error_log "Couldn't find 'hdbinst' in $QUICKSTART_SAP_EXTRACTION_DIR/*"; return 1
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
        error_log "Couldn't find 'hdblcm' in $QUICKSTART_SAP_EXTRACTION_DIR/*"; return 1
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
        error_log "Couldn't find 'hdblcm' in $QUICKSTART_SAP_EXTRACTION_DIR/*"; return 1
    fi
    echo '<?xml version="1.0" encoding="UTF-8"?><Passwords>
    <password><![CDATA['${master_pass}']]></password>
    <sapadm_password><![CDATA['${master_pass}']]></sapadm_password>
    <system_user_password><![CDATA['${master_pass}']]></system_user_password>
    <root_password><![CDATA['${login_password}']]></root_password>
    </Passwords>' | ${hdblcm_path} --action=install --components=client,server --batch --autostart=1 -sid="${hana_sid}"  --hostname="${ecs_hostname}" --number="${instance_number}" --userid="${hana_sap_sid_adm_uid}" --groupid="${hana_sap_sys_gid}" --system_usage="${system_usage}" --read_password_from_stdin=xml  >/dev/null || return 1
}

#Define HSR validation function
#check_state
function check_state(){
    state=$(run_cmd "cdpy ; python systemReplicationStatus.py" "${HANASidAdm}")
    [[ "${state}" == "this system is not a system replication site" ]] && return 2
    $(echo ${state} | grep -q 'status system replication site \"2\": INITIALIZING') && return 3
    $(echo ${state} | grep -q 'overall system replication status: INITIALIZING') && return 3
    $(echo ${state} | grep 'status system replication site \"2\": ACTIVE' | grep -q 'overall system replication status: ACTIVE') && return 0

    warning_log "${state}"
    return 1
}

#Define HSR configuration function
#hsr_config 
function hsr_config(){
    info_log "Start to configure HANA HSR"
    BACKUP_PREFIX="COMPLETE_DATA_BACKUP_`date +%Y%m%d_%H_%M_%S`"
    systemDB_path="/usr/sap/${HANASID}/HDB${HANAInstanceNumber}/backup/data/SYSTEMDB/${BACKUP_PREFIX}"
    teanentDB_path="/usr/sap/${HANASID}/HDB${HANAInstanceNumber}/backup/data/DB_${HANASID}/${BACKUP_PREFIX}"
    check_state > /dev/null
    state=$?
    if [ ${state} -eq 0 ];then
        info_log "HANA HSR status is active,don't need to configure"
        return 0
    fi
    info_log "Start to initial SYSTEMDB and tenantDB backup for HSR"
    run_cmd "mkdir -p ${systemDB_path}" "${HANASidAdm}"
    run_cmd "mkdir -p ${teanentDB_path}" "${HANASidAdm}"
    run_cmd "hdbsql -t -u SYSTEM -p ${MasterPass} -d SYSTEMDB \"backup data using file('${systemDB_path}')\"" "${HANASidAdm}" || { error_log "Backup SYSTEMDB failed"; return 1; }
    run_cmd "hdbsql -t -u SYSTEM -p ${MasterPass} -d ${HANASID} \"backup data using file('${teanentDB_path}')\"" "${HANASidAdm}" || { error_log "Backup TeanentDB failed"; return 1; }

    scp /usr/sap/${HANASID}/SYS/global/security/rsecssfs/data/SSFS_${HANASID}.DAT root@${ClusterMemberHostname}:/usr/sap/${HANASID}/SYS/global/security/rsecssfs/data/SSFS_${HANASID}.DAT || { error_log "Sync SSFS_${HANASID}.DAT file failed"; return 1; }
    scp /usr/sap/${HANASID}/SYS/global/security/rsecssfs/key/SSFS_${HANASID}.KEY root@${ClusterMemberHostname}:/usr/sap/${HANASID}/SYS/global/security/rsecssfs/key/SSFS_${HANASID}.KEY  || { error_log "Sync SSFS_${HANASID}.KEY file failed"; return 1; }
    run_cmd "hdbnsutil -sr_enable --name=site1" "${HANASidAdm}" || { error_log "HSR register first site failed"; return 1; }
    run_cmd_remote "${ClusterMemberHostname}" "su - ${HANASidAdm} -c 'sapcontrol -nr ${HANAInstanceNumber} -function StopSystem'"
    for num in $(seq 1 12)
    do 
        sleep 30
        run_cmd_remote "${ClusterMemberHostname}" "su - ${HANASidAdm} -c 'sapcontrol -nr ${HANAInstanceNumber} -function GetProcessList'"
        if [ $? == '4' ]; then
            run_cmd_remote "${ClusterMemberHostname}" "su - ${HANASidAdm} -c 'hdbnsutil -sr_register --remoteHost=${ECSHostname} --remoteInstance=${HANAInstanceNumber} --replicationMode=syncmem --name=site2 --remoteName=site1 --operationMode=logreplay'"
            if [ $? -eq '0' ]; then
                num=0
                break
            fi
        fi
    done
    if [ ${num}  -ne '0' ];then
            return 1
    fi
    
    run_cmd_remote "${ClusterMemberHostname}" "su - ${HANASidAdm} -c 'sapcontrol -nr ${HANAInstanceNumber} -function StartSystem'"
    
    for num in $(seq 1 12)
    do 
        sleep 30
        run_cmd_remote "${ClusterMemberHostname}" "su - ${HANASidAdm} -c 'sapcontrol -nr ${HANAInstanceNumber} -function GetProcessList'"
        if [ $? == '3' ];then
            num=0
            break
        fi
    done
    if [ ${num}  -ne '0' ];then
            return 1
    fi

    check_state
    state=$?
    if [ ${state} -eq 0 ];then
        info_log "HSR configuration has been finshed sucessful"
        return 0
    elif [ ${state} -eq 3 ];then
        sleep 5m
        check_state
        if [ $? -eq 0 ];then
            info_log "HSR configuration has been finshed sucessful"
            return 0
        fi
    elif [ ${state} -eq 1 ];then
        error_log "HSR configuration error"
    fi
    return 1
}

#Define corosync configuration function
#corosync_config
function corosync_config(){
    info_log "Start to configure corosync"
    wget -nv "${CorosyncConfigurationTemplateURL}" -O "${CorosyncConfigurationTemplatePath}"
    if ! [[ -s "${CorosyncConfigurationTemplatePath}" ]];then
        error_log "Download corosync configuration template failed url:${CorosyncConfigurationTemplateURL}"
        return 1
    fi
    content=$(cat ${CorosyncConfigurationTemplatePath})
    eval "cat <<EOF
    $content
EOF"  > /etc/corosync/corosync.conf
    scp /etc/corosync/corosync.conf ${ClusterMemberHostname}:/etc/corosync/corosync.conf || { error_log "Sync corosync.conf file failed"; return 1; }
    info_log "Corosync configuration has been finished sucessful"
}

#Define Resource configuration function
#resource_config
function resource_config(){
    info_log "Start to configure HA resource agent"
    wget -nv "${ResourcesConfigurationTemplateURL}" -O "${ResourcesConfigurationTemplatePath}"
    if ! [[ -s "${ResourcesConfigurationTemplatePath}" ]];then
        error_log "Download HANA HA configuration template failed url:${ResourcesConfigurationTemplateURL}"
        return 1
    fi
    id='$id'
    content=$(cat ${ResourcesConfigurationTemplatePath})
    eval "cat <<EOF
    ${content//\\/\\\\}
EOF"  > "${ResourcesConfigurationFilePath}"
    systemctl start pacemaker || { error_log "Start pacemaker failed"; return 1; }
    ssh ${ClusterMemberHostname} "systemctl start pacemaker" 
    crm configure load update "${ResourcesConfigurationFilePath}"
    if [ $? -ne 0 ];then
        error_log "crm load template failed"
        return 1
    fi
    info_log "HA resource agent configuration have been finished sucessful"
}

#Define HA validation function
HA_validation(){
    info_log "Start to validate HANA HA"
    res_validation "rsc_sbd" "rsc_sbd.*Started" || return 1
    res_validation "rsc_vip" "rsc_vip.*Started" || return 1
    res_validation "Masters" "Masters: \[ ${ECSHostname} \]" || return 1
    res_validation "Slaves" "Slaves: \[ ${ClusterMemberHostname} \]" || return 1
    res_validation "Server Status" "Started: \[ ${ECSHostname} ${ClusterMemberHostname} \]" || return 1
    crm resource cleanup rsc_SAPHana_HDB
    info_log "HANA HA configuration have been finished,please check it manually"
    return 0
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
            HA_packages || return 1
            if [[ -n "${S4Hostname}" ]];then
                APP_post
            else
                HANA_post
            fi
            ;;
        7)
            config_eni "${ECSHeartIpAddress}" "${HeartNetworkCard}" || return 1
            info_log "Configure elastic network card successful"
            ;;
        8)
            ssh_setup "${ClusterMemberHostname}" "root" "${LoginPassword}" || return 1
            ssh_setup "${ClusterMemberHostname}" "${HANASidAdm}" "${MasterPass}" || return 1
            info_log "Configure SSH trust successful"
            ;;
        9)
            wait_HANA_ECS "${ClusterMemberIpAddress}" "${HANAInstanceNumber}" || return 1
            if [ "${NodeType}" == "Master" ];then
                hsr_config || return 1
            fi
            ;;
        10)
            sbd_config "${HAQuorumDisk}" || return 1
            if [ "${NodeType}" == "Master" ];then
                corosync_config || return 1
            fi
            ;;
        11)
            if [ "${NodeType}" == "Master" ];then
                resource_config || return 1
                sleep 3m
                HA_validation 
            fi
            start_hawk "${MasterPass}"
            ;;
        *)
            error_log "Can't match Mark value,please check whether modify the Mark file"
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