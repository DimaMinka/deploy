#!/bin/bash
#
# git.sh
#
###############################################################################
# Handles git related processes
###############################################################################
trace "Loading git functions"

# Assign a variable to represent .git/index.lock
gitLock="${WORKPATH}/${APP}/.git/index.lock"

# Make sure we're in a git repository.
function gitStart() {
  # Directory exists?
  if [[ ! -d "${WORKPATH}/${APP}" ]]; then
    info "${WORKPATH}/${APP} is not a valid directory."
    exit 1
  else
    cd "${WORKPATH}/${APP}" || errorChk
  fi

  # Check that .git exists
  if [[ -f "${WORKPATH}/${APP}/.git/index" ]]; then
    sleep 1
  else
    info "There is nothing at ${WORKPATH}/${APP} to deploy."
    exit 1
  fi

  # If CHECKBRANCH is set, make sure current branch is correct.
  start_branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ -n "${CHECKBRANCH}" ]] && [[ "${DIGEST}" != "1" ]] && [[ "${PROJSTATS}" != "1" ]] && [[ "${EMAILTEST}" != "1" ]] && [[ "${SLACKTEST}" != "1" ]]; then 
    if [[ "${start_branch}" != "${CHECKBRANCH}" ]]; then
      error "Must be on ${CHECKBRANCH} branch to continue deployment.";
    fi
  fi

  # Check for active files
  activeChk

  # Try to clear out old git processes owned by this user, if they exist
  killall -9 git &>> /dev/null || true
}

# Checkout master
function gitChkMstr() {
  if [[ -z "${MASTER}" ]]; then
    emptyLine; error "deploy ${VERSION} requires a master branch to be defined.";
  else
    current_branch="$(git rev-parse --abbrev-ref HEAD)"
    if [[ "${current_branch}" != "${MASTER}" ]]; then
      notice "Checking out master branch..."; fixIndex
      if [[ "${VERBOSE}" -eq 1 ]]; then
        git checkout master | tee --append "${logFile}"            
      else
        if [[ "${QUIET}" != "1" ]]; then
          git checkout master &>> "${logFile}" &
          showProgress
        else
          git checkout master &>> "${logFile}"
        fi
      fi
    fi
  fi
}

# Garbage collection
function gitGarbage() {
  if [[ "${GARBAGE}" = "TRUE" ]] && [[ "${QUIET}" != "1" ]]; then 
    notice "Preparing repository..."
    git gc | tee --append "${logFile}"
    if [[ "${QUIET}" != "1" ]]; then
      git gc &>> "${logFile}"
    fi
  fi
}

# Does anything need to be committed? (Besides me?)
function gitStatus() {
  if [[ -z "$(git status --porcelain)" ]]; then
    if [[ "${APPROVE}" != "1" ]] && [[ "${DENY}" != "1" ]]; then
      if [[ "${REQUIREAPPROVAL}" == "TRUE" ]]; then
        console "Nothing to queue, working directory clean."
      else
        console "Nothing to commit, working directory clean."
      fi
      quietExit
    fi
  fi
}

# Stage files
function gitStage() {
  # Check for stuff that needs a commit
  if [[ -z $(git status --porcelain) ]]; then
    console "Nothing to commit, working directory clean."; quietExit
  else
    emptyLine
    if [[ "${FORCE}" = "1" ]] || yesno --default yes "Stage files? [Y/n] "; then
      trace "Staging files"
      if [[ "${VERBOSE}" -eq 1 ]]; then
        git add -A | tee --append "${logFile}"; errorChk              
      else  
        git add -A &>> "${logFile}"; errorChk
      fi
    else
      trace "Exiting without staging files"; userExit    
    fi
  fi
}

# Commit, with message
function gitCommit() {
  # Smart commit stuff
  smrtCommit; emptyLine

  # Do a dry run; check for anything to commit
  git commit --dry-run &>> "${logFile}" 
  if grep -q "nothing to commit, working directory clean" "${logFile}"; then 
    info "Nothing to commit, working directory clean."
    safeExit
  else
    # Found stuff, let's get a commit message
    if [[ -z "${COMMITMSG}" ]]; then
      # while read -p "Enter commit message: " notes && [[ -z "$notes" ]]; do :; done
      read -rp "Enter commit message: " notes
      if [[ -z "${notes}" ]]; then
        console "Commit message must not be empty."
        read -rp "Enter commit message: " notes
        if [[ -z "${notes}" ]]; then
          console "Really?"
          read -rp "Enter commit message: " notes
        fi
        if [[ -z "${notes}" ]]; then
          console "Last chance."
          read -rp "Enter commit message: " notes
        fi
        if [[ -z "${notes}" ]]; then
          quickExit
        fi
      fi
    else
      # If running in -Fu (force updates only) mode, grab the Smart Commit 
      # message and skip asking for user input. Nice for cron updates. 
      if [[ "${FORCE}" = "1" ]] && [[ "${UPDATE}" = "1" ]]; then
        # We need Smart commits enabled or this can't work
        if [[ "${SMARTCOMMIT}" -ne "TRUE" ]]; then
          console "Smart Commits must enabled when forcing updates."
          console "Set SMARTCOMMIT=TRUE in ${WORKPATH}/${APP}/${CONFIGDIR}deploy.sh"; quietExit
        else
          if [[ -z "${COMMITMSG}" ]]; then
            info "Commit message must not be empty."; quietExit
          else
            notes="${COMMITMSG}"
          fi
        fi
      else
        # We want to be able to edit the default commit if available
        if [[ "${FORCE}" != "1" ]]; then
          notes="${COMMITMSG}"
          read -rp "Edit commit message: " -e -i "${COMMITMSG}" notes
          # Update the commit message based on user input ()
          notes="${notes:-$COMMITMSG}"
        else
          info "Using auto-generated commit message: ${COMMITMSG}"
          notes="${COMMITMSG}"
        fi
      fi
    fi

    if [[ "${REQUIREAPPROVAL}" == "TRUE" ]] && [[ "${APPROVE}" != "1" ]] && [[ "${DENY}" != "1" ]]; then 
      trace "Queuing commit message"
      echo "${notes}" > "${WORKPATH}/${APP}/.queued"
    else
      git commit -m "${notes}" &>> "${logFile}"; errorChk
      trace "Commit message: ${notes}"
    fi
  fi

  # Check for bad characters in commit message
  echo "${notes}" > "${trshFile}"
  sed -i "s/\&/and/g" "${trshFile}"
  notes=$(<$trshFile)
}

# Push master
function gitPushMstr() {
  if [[ -n "${MASTER}" ]]; then
    trace "Pushing ${MASTER}"; fixIndex
    emptyLine  
    if [[ "${VERBOSE}" -eq 1 ]]; then
      git push | tee --append "${logFile}"; errorChk           
    else
      if  [[ "${FORCE}" = "1" ]] || yesno --default yes "Push ${MASTER} branch? [Y/n] "; then
        if [[ "${NOKEY}" != "TRUE" ]]; then
          if [[ "${QUIET}" != "1" ]]; then
            git push &>> "${logFile}" &
            spinner $!
            info "Success.    "
          else
            git push &>> "${logFile}"; errorChk
          fi
        else
          git push &>> "${logFile}"; errorChk
        fi
      else
        safeExit
      fi
    fi
  fi
}

# Checkout production, now with added -f
function gitChkProd() {
  if [[ "${MERGE}" = "1" ]]; then
    if [[ -n "${PRODUCTION}" ]]; then
      notice "Checking out ${PRODUCTION} branch..."; fixIndex

      if [[ "${VERBOSE}" -eq 1 ]]; then
        git checkout "${PRODUCTION}" | tee --append "${logFile}"; errorChk               
      else
        if [[ "${QUIET}" != "1" ]]; then
          git checkout "${PRODUCTION}" &>> "${logFile}" &
          spinner $!
          info "Success.    "
        else
          git checkout "${PRODUCTION}" &>> "${logFile}"; errorChk
        fi
      fi

      # Make sure the branch currently checked out is production, if not
      # then let's try a ghetto fix
      sleep 3; current_branch="$(git rev-parse --abbrev-ref HEAD)"
      if [[ "${current_branch}" != "${PRODUCTION}" ]]; then
        # If we're in that weird stuck mode on master, let's try to "fix" it
        if  [[ "${FORCE}" = "1" ]] || yesno --default yes "Current branch is ${current_branch} and should be ${PRODUCTION}, try again? [Y/n] "; then
          if [[ "${current_branch}" = "${MASTER}" ]]; then 
            [[ -f "${gitLock}" ]] && rm "${gitLock}"
            git add .; git checkout "${PRODUCTION}" &>> "${logFile}" #; errorChk
          fi
        else
          safeExit
        fi
      fi

      # Were there any conflicts checking out?
      if grep -q "error: Your local changes to the following files would be overwritten by checkout:" "${logFile}"; then
         error "There is a conflict checking out."
      else
        trace "OK"
      fi
    fi
  fi
}

# Merge master into production
# git merge --no-edit might be bugging, took it our for now
function gitMerge() {
  if [[ "${MERGE}" = "1" ]]; then
    if [[ -n "${PRODUCTION}" ]]; then
      notice "Merging ${MASTER} into ${PRODUCTION}..."; fixIndex
      # Clear out the index.lock file, cause reasons
      [[ -f "${gitLock}" ]] && rm "${gitLock}"
      # Bonus add, just because. Ugh.
      # git add -A; errorChk 
      if [[ "${VERBOSE}" -eq 1 ]]; then
        git merge "${MASTER}" | tee --append "${logFile}"              
      else
        if [[ "${QUIET}" != "1" ]]; then
          # git merge --no-edit master &>> "${logFile}" &
          git merge "${MASTER}" &>> "${logFile}" &
          showProgress
        else
          git merge "${MASTER}"&>> "${logFile}"; errorChk
        fi
      fi
    fi
  fi
}

# Push production
function gitPushProd() {
  if [[ "${MERGE}" = "1" ]]; then
    if [[ -n "${PRODUCTION}" ]]; then
      trace "Push ${PRODUCTION}"; fixIndex
      emptyLine
      if [[ "${VERBOSE}" -eq 1 ]]; then
        git push | tee --append "${logFile}"; errorChk 
        trace "OK"              
      else
        if [[ "${FORCE}" = "1" ]] || yesno --default yes "Push ${PRODUCTION} branch? [Y/n] "; then
          if [[ "${QUIET}" != "1" ]]; then
            sleep 1
            git push &>> "${logFile}" &
            spinner $!
            info "Success.    "
          else
            git push &>> "${logFile}"; errorChk
          fi
          sleep 1
          if [[ $(git status --porcelain) ]]; then
            sleep 1; git add . &>> "${logFile}"
            git push --force-with-lease  &>> "${logFile}"
          fi
        else
          safeExit
        fi
      fi
    fi

    # This is here temporarily to doubleplus force through a buggish situation
    git checkout production &>> "${logFile}"
    git merge master &>> "${logFile}"
    git push &>> "${logFile}"
  fi
}

# Get the stats for this git author, just for fun
function gitStats() {
  if [[ "${GITSTATS}" == "TRUE" ]] && [[ "${QUIET}" != "1" ]] && [[ "${PUBLISH}" != "1" ]]; then
    console "Calculating..."
    getent passwd "${USER}" | cut -d ':' -f 5 | cut -d ',' -f 1 > "${trshFile}"
    FULLUSER=$(<"${trshFile}")
    git log --author="${FULLUSER}" --pretty=tformat: --numstat | \
    # The single quotes were messing with trying to line break this one
    gawk '{ add += $1 ; subs += $2 ; loc += $1 - $2 } END { printf "Your total lines of code contributed so far: %s\n(+%s added | -%s deleted)\n",loc,add,subs }' -
  fi
} 
