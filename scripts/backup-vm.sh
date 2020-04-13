#!/bin/sh
DIR_SCRIPT=/vmfs/volumes/datastore1/scripts
#DATETIME_OF_BACKUP=$(echo $(date +%Y-%m-%d-%T) | sed -e 's/\:/\\:/g')
DATETIME_OF_BACKUP=$(date +%Y-%m-%d-%T)
DATE_OF_BACKUP=$(date +%Y-%m-%d)
VM_NAME="$1"
VM_NAME_TRIMMED=$(echo $1 | sed -e 's/ //g')
TRANSFER_MODE=$2
SERVER_REMOTE=$3
USER_REMOTE=$4
DIR_REMOTE=$5
DIR_VM="/vmfs/volumes/datastore1/${VM_NAME}"
DIR_TARGET_BASE="/vmfs/volumes/datastore1/backup"
DIR_TARGET="${DIR_TARGET_BASE}/${VM_NAME_TRIMMED}_${DATETIME_OF_BACKUP}"
DIR_TARGET_ARCHIVE="${DIR_TARGET_BASE}/${VM_NAME_TRIMMED}*"
DIR_TARGET_TRANSFER="${DIR_TARGET_BASE}/${VM_NAME_TRIMMED}_${DATE_OF_BACKUP}*"
FILE_LOG="${DIR_SCRIPT}/${VM_NAME_TRIMMED}.log"

execute() {
        echo "Executing:  $1" | awk '{RS=""; FS="\n"} {print strftime("%Y-%m-%d %T %Z")" - "$0}' >> ${FILE_LOG}
        $1 >> ${FILE_LOG} 2>&1
        echo "Done." | awk '{RS=""; FS="\n"} {print strftime("%Y-%m-%d %T %Z")" - "$0}' >> ${FILE_LOG}
}

log() {
        echo "$1" | awk '{RS=""; FS="\n"} {print strftime("%Y-%m-%d %T %Z")" - "$0}' >> ${FILE_LOG}
}

log "======================================================================================"


log "Identify VM ID for ${VM_NAME}"
vmid=$(vim-cmd vmsvc/getallvms 2>/dev/null | grep "${VM_NAME}" | awk '{print $1}')

if [ -z "${vmid}" ]; then
        log "Didn't get VM ID for ${VM_NAME}"
else
        log "Identified ${VM_NAME} as ${vmid}"

        mkdir -p "${DIR_TARGET}"

        cp -rp "${DIR_VM}/${VM_NAME}.vmx" "${DIR_TARGET}/."
        cp -rp "${DIR_VM}/${VM_NAME}.nvram" "${DIR_TARGET}/."
        cp -rp "${DIR_VM}/${VM_NAME}.vmsd" "${DIR_TARGET}/."

        log "Create snapshot for ${VM_NAME}"
        vim-cmd vmsvc/snapshot.create ${vmid} "${VM_NAME} ${DATETIME_OF_BACKUP}" 'Snapshot created by Backup Script' 1 1

        log "Clone VM for ${VM_NAME}"
        vmkfstools -i "${DIR_VM}/${VM_NAME}.vmdk" "${DIR_TARGET}/${VM_NAME}.vmdk" -d thin

        log "Remove snapshot for ${VM_NAME}"
        vim-cmd vmsvc/snapshot.removeall ${vmid}

        log "Transfer to ${USER_REMOTE}@${SERVER_REMOTE}:${DIR_REMOTE} via ${TRANSFER_MODE}"
        if [ "${TRANSFER_MODE}" == "scp" ]; then
                CMD="scp -r ${DIR_TARGET_TRANSFER} ${USER_REMOTE}@${SERVER_REMOTE}:${DIR_REMOTE}"
                execute "${CMD}"
        elif [ "${TRANSFER_MODE}" == "rsync" ]; then
                CMD="rsync --timeout=10 -azP ${DIR_TARGET_TRANSFER} ${USER_REMOTE}@${SERVER_REMOTE}:${DIR_REMOTE}"
                execute "${CMD}"
        else
                log "Incorrect transfer mode provided."
        fi

        log "Archive by deleting previous backups"
        CMD="find ${DIR_TARGET_BASE} -name '${VM_NAME_TRIMMED}*' -type d -mtime +2 -exec rm -rf {} +"
        echo "${CMD}"
        CMD="find ${DIR_TARGET_BASE} -name '${VM_NAME_TRIMMED}*' -type d -mtime +2 -exec rm -rf {} +"
        execute "${CMD}"

fi