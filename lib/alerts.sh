#!/bin/bash
#
# alerts.sh

black='\E[30;47m'
red='\e[0;31m'
green='\e[0;32m'
yellow='\E[33;47m'
blue='\E[34;47m'
magenta='\E[35;47m'
cyan='\E[36;47m'
white='\E[37;47m'
bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)
purple=$(tput setaf 171)
tan=$(tput setaf 3)
endColor='\e[0m'

function info () {
  if [[ $QUIET != "1" ]]; then
    echo -e "${reset}$@${endColor}"
  fi
}

function notice () {
  if [[ $QUIET != "1" ]]; then
    echo; echo -e "${green}$@${endColor}"
#  else
  fi
}

function error () {
  echo -e "${red}$@${endColor}"
  safeExit
}

function warning () {
  if [[ $QUIET != "1" ]]; then
    echo -e "${red}$@${endColor}"
  fi
}

function emptyLine () {
  if [[ $QUIET != "1" ]]; then
    echo ""
  fi
}