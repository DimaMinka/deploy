#!/bin/bash
#
# wp-core.sh
#
###############################################################################
# Checks for Wordpress core updates
###############################################################################

function wpCore() {
  # There's a little bug when certain plugins are spitting errors; work around 
  # seems to be to check for core updates a second time
  cd "${WORKPATH}"/"${APP}${WPROOT}"; \
  "${WPCLI}"/wp core check-update --no-color &>> "${logFile}"
  if grep -q 'WordPress is at the latest version.' "${logFile}"; then
    info "Wordpress core is up to date."; UPD2="1"
  else
    sleep 1
    # Get files setup for smart commit
    "${WPCLI}"/wp core check-update --no-color &> "${coreFile}"
    
    # Strip out any randomly occuring debugging output
    grep -vE 'Notice:|Warning:|Strict Standards:|PHP' "${coreFile}" > "${trshFile}" && mv "${trshFile}" "${coreFile}";
    
    # Clean out the gobbleygook from wp-cli
    sed 's/[+|-]//g' "${coreFile}" > "${trshFile}" && mv "${trshFile}" "${coreFile}";
    cat "${coreFile}" | awk 'FNR == 1 {next} {print $1}' > "${trshFile}" && mv "${trshFile}" "${coreFile}";
    
    # Just in case, try to remove all blank lines. DOS formatting is 
    # messing up output with PHP crap
    sed '/^\s*$/d' "${coreFile}" > "${trshFile}" && mv "${trshFile}" "${coreFile}";
    
    # Remove line breaks, value should noe equal 'version x.x.x' or 
    # some such.
    sed ':a;N;$!ba;s/\n/ /g' "${coreFile}" > "${trshFile}" && mv "${trshFile}" "${coreFile}";
    COREUPD=$(<$coreFile)

    if [[ -n "${COREUPD}" ]]; then
      # Update available!  \o/
      echo -e "";

      # Check for broken wp-cli garbage
      if [[ "${COREUPD}" == *"PHP"* ]]; then
        warning "Checking for available core update was unreliable, skipping.";
      else
        if [[ "${FORCE}" = "1" ]] || yesno --default no "A new version of Wordpress is available (${COREUPD}), update? [y/N] "; then
          cd "${WORKPATH}/${APP}${WPROOT}"; \
          if [[ "${QUIET}" != "1" ]]; then
            "${WPCLI}"/wp core update --no-color &>> "${logFile}" &
            spinner $!
          else
            "${WPCLI}"/wp core update --no-color &>> "${logFile}"
          fi

          # Double check upgrade was successful if we still see 
          # 'version' in the output, we must have missed the upgrade 
          # somehow
          "${WPCLI}"/wp core check-update --quiet --no-color &> "${trshFile}"
          if grep -q "version" "${trshFile}"; then
            error "Core update failed.";
          else
            sleep 1
            cd "{$WORKPATH}/${APP}/"; # \ 
            info "Wordpress core updates complete."; UPDCORE=1
          fi
                  
          # Update staging server database if needed
          if [[ "${UPDCORE}" = "1" ]] && [[ -n "${DEVURL}" ]]; then
            info "Upgrading staging database..."; curl --silent "${DEVURL}${WPSYSTEM}"/wp-admin/upgrade.php?step=1 >/dev/null 2>&1
          fi                          
        else
          info "Skipping Wordpress core updates..."
        fi
      fi
    fi
  fi  
}
