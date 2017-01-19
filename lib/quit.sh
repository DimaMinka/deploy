#!/bin/bash
#
# quit.sh
#
# Handles exiting the program
trace "Loading exit states"

# User-requested exit
function userExit() {
	rm "${WORKPATH}/${APP}/.git/index.lock" &> /dev/null
	trace "Exit on user request"
	# Check email settings
	if [ "${EMAILQUIT}" == "TRUE" ]; then
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
	if [ "${EMAILERROR}" == "TRUE" ]; then
		mailLog
	fi

	# Check Slack settings
	if [ "${POSTTOSLACK}" == "TRUE" ] && [ "${SLACKERROR}" == "TRUE" ]; then
		message_state="ERROR"
		slackPost
	fi

  	# Clean up your mess
	cleanUp; exit 1
}

# Clean exit
function safeExit() {
	info "Exiting."; console
	makeLog # Compile log
	# Check email settings
	if [ "${EMAILSUCCESS}" == "TRUE" ]; then
	   mailLog
	fi
	# Clean up your mess
	cleanUp; exit 0
}

# Clean exit, nothing to commit
function quietExit() {
	info "Exiting."; console
	# Clean up your mess
	cleanUp; exit 0
}

function cleanUp() {
	# If anything is stashed, unstash it.
	if [[ "${currentStash}" = "1" ]]; then
		git stash pop >> "${logFile}"
		currentStash="0"
	fi	
	[[ -f $logFile ]] && rm "$logFile"
	[[ -f $trshFile ]] && rm "$trshFile"
	[[ -f $postFile ]] && rm "$postFile"
	[[ -f $statFile ]] && rm "$statFile"
	[[ -f $wpFile ]] && rm "$wpFile"
	[[ -f $urlFile ]] && rm "$urlFile"
	[[ -f $htmlFile ]] && rm "$htmlFile"
	[[ -f $htmlEmail ]] && rm "$htmlEmail"
	[[ -f $clientEmail ]] && rm "$clientEmail"
	[[ -f $coreFile ]] && rm "$coreFile"
	# [[ -f $gitLock ]] && rm "$gitLock"
	# Attempt to reset the terminal
	# echo -e \\033c

	# If Wordfence was an issue, restart the plugin
	if [[ "${WFOFF}" = "1" ]]; then
		"${WPCLI}"/wp plugin activate --no-color wordfence &>> $logFile; errorChk
	fi
	if [ "$QUIET" != "1" ]; then
		tput cnorm
	fi
}
