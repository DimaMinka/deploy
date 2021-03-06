#!/bin/bash
#
# quit.sh
#
###############################################################################
# Handles exiting the program
###############################################################################
trace "Loading exit states"

# User-requested exit
function userExit() {
  rm "${WORKPATH}/${APP}/.git/index.lock" &> /dev/null
  trace "Exit on user request"
  # Check email settings
  if [[ "${EMAILQUIT}" == "TRUE" ]]; then
     mailLog
  fi
  # Clean up your mess
  cleanUp; exit 0
}

# Quick exit, never send log. Ever.
function quickExit() {
  # Clean up your mess
  cleanUp; exit 0
}

# Exit on error
function errorExit() {
  message_state="ERROR"; makeLog # Compile log
  # Check email settings
  if [[ "${EMAILERROR}" == "TRUE" ]]; then
    mailLog
  fi

  # Check Slack settings
  if [[ "${POSTTOSLACK}" == "TRUE" ]] && [[ "${SLACKERROR}" == "TRUE" ]]; then
    message_state="ERROR"
    slackPost
  fi

    # Clean up your mess
  cleanUp; exit 1
}

# Clean exit
function safeExit() {
  makeLog # Compile log
  # Check email settings
  if [[ "${EMAILSUCCESS}" == "TRUE" ]]; then
     mailLog
  fi

  # Is Slack integration configured?
  # Ghetto but will do for now
  if [[ "${POSTTOSLACK}" == "TRUE" ]] && [[ "${AUTOMATE}" == "1" ]] && [[ "${APPROVE}" != "1" ]] && [[ "${UPD1}" = "1" ]] && [[ "${UPD2}" = "1" ]]; then
    message_state="NOTICE"
    notes="No updates available for deployment"
    slackPost
  else
    if [[ "${POSTTOSLACK}" == "TRUE" ]]; then
      trace "Posting to Slack"
      buildLog; slackPost > /dev/null 2>&1
    fi
  fi

  # Clean up your mess
  cleanUp; exit 0
}

# Clean exit, nothing to commit
function quietExit() {
  # Clean up your mess
  cleanUp; exit 0
}

function cleanUp() {
  # If anything is stashed, unstash it.
  if [[ "${currentStash}" == "1" ]]; then
    trace "Unstashing files"
    git stash pop >> "${logFile}"
    currentStash="0"
  fi  
  [[ -f "${logFile}" ]] && rm "${logFile}"
  [[ -f "${trshFile}" ]] && rm "${trshFile}"
  [[ -f "${postFile}" ]] && rm "${postFile}"
  [[ -f "${statFile}" ]] && rm "${statFile}"
  [[ -f "${wpFile}" ]] && rm "${wpFile}"
  [[ -f "${urlFile}" ]] && rm "${urlFile}"
  [[ -f "${htmlFile}" ]] && rm "${htmlFile}"
  [[ -f "${htmlEmail}" ]] && rm "${htmlEmail}"
  [[ -f "${clientEmail}" ]] && rm "${clientEmail}"
  [[ -f "${coreFile}" ]] && rm "${coreFile}"
  # [[ -f "${gitLock}" ]] && rm "${gitLock}"
  # Attempt to reset the terminal
  # echo -e \\033c

  # Make sure we leave the repo as we found it
  if [[ -n "${start_branch}" ]]; then
    current_branch="$(git rev-parse --abbrev-ref HEAD)"
    if [[ "${current_branch}" != "${start_branch}" ]]; then
      git checkout "${start_branch}" &>> "${logFile}" &
    fi
  fi

  # If Wordfence was an issue, restart the plugin
  if [[ "${WFOFF}" = "1" ]]; then
    "${WPCLI}"/wp plugin activate --no-color wordfence &>> $logFile; errorChk
  fi

  # Was this an approval?
  if [[ "${APPROVE}" == "1" ]]; then
    if [[ -f "${WORKPATH}/${APP}/.queued" ]] && [[ "${message_state}" != "ERROR" ]]; then 
      rm "${WORKPATH}/${APP}/.queued"
    fi
    if [[ -f "${WORKPATH}/${APP}/.approved" ]]; then
      rm "${WORKPATH}/${APP}/.approved"
    fi
  fi

  # Attempt to reset the console when running --quiet
  if [[ "${QUIET}" != "1" ]]; then
    tput cnorm
  fi

  # Say goodnight, Gracie. Goodnight Gracie.
  info "Exiting."; console
}
