#!/bin/bash
#
# smrtCommit()
#
# Tries to create "Smart Commit" messages based on parsing
# output from wp-cli.
trace "Loading smrtCommit()"

# Constructing smart *cough* commit messages
function smrtCommit() {
  if [[ $SMRTCOMMIT == 1 ]]; then
    trace "Building commit message"
    # Checks for the existence of a successful plugin upgrade, using grep
    PCA=$(grep '\<Success: Updated' $logFile | grep 'plugins')
    if [[ -z "$PCA" ]]; then
      trace "No plugin updates"
    else
      # Yanks out the "Success: "
      PCB=$(echo $PCA | sed 's/^.*\(Updated.*\)/\1/g')
      # Strips the last period, makes my head hurt.
      PCC=${PCB%?}; PCD=$(echo $PCB | cut -c 1-$(expr `echo "$PCC" | wc -c` - 2))
      trace "Plugin status ["$PCD"]"
      # Replace current commit message with Plugin upgrade info 
      COMMITMSG=$PCD
      # Will have to add the stuff for core upgrade, still need logs
      #
    fi
  fi
}