#!/bin/bash
#
# lock.sh
#
###############################################################################
# Locks deployment process
###############################################################################
trace "Locking process"

# Define lock file location
LOCK_FILE="/tmp/$APP.lock"

function lock() {

  if [[ -f "${LOCK_FILE}" ]]; then
    # Unlock?
    if [[ "${UNLOCK}" == "1" ]]; then
      rm "${LOCK_FILE}"
      notice "${WORKPATH}/${APP} is now unlocked."
      quietExit
    else
      warning "${WORKPATH}/${APP} is already being deployed in another instance."
      quietExit
    fi
  else
    trap 'rm -f "${LOCK_FILE}"' EXIT
    trace "Creating lockfile"
      touch "${LOCK_FILE}"
  fi
}
