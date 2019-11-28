#!/usr/bin/env bash

#   __          _______   _      _
#   \ \        / / ____| | |    (_)
#    \ \  /\  / / |  __  | |     _  __ _  __ _ ___  ___
#     \ \/  \/ /| | |_ | | |    | |/ _` |/ _` / __|/ _ \
#      \  /\  / | |__| | | |____| | (_| | (_| \__ \  __/
#       \/  \/   \_____| |______|_|\__, |\__,_|___/\___|
#                                   __/ |
#                                  |___/
# This is a simple bash script to aid in configuring WireGuard tunnels and clients.
# Q: Hasn't this been done bedofe?
# A: Probably.
# Q: Why another WG configuration script?
# A: Why not?
# Q: ....Ligase???
# A: In biochemistry, a ligase is an enzyme that can catalyze the joining of two large molecules by forming a new chemical bond -
# - https://en.wikipedia.org/wiki/Ligase (May 19th, 2019)

if [ "$EUID" -ne 0 ]; then
  echo "Please run the script as root."
  exit 1
fi

my_wgl_folder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source "$my_wgl_folder"/doc/functions.sh
# Setting the colours function
colours

logo=$(cat "$my_wgl_folder"/doc/ascii-logo)
printf '\e[2J\e[H'
printf %b\\n "${BPurple}$logo${Color_Off}"

printf %b\\n "${BWhite}Welcome to WG Ligase${Color_Off}.

The script will guide you through the installaton process, allowing to
choose a starting point. The idea is for this script to be equally
suitable for new deployments, as well as for configuring a live
deployment.
"

printf %b\\n "
Let's begin. Please select from one of the following options:
-----------------------------------

${BWhite}1 = Normal Setup:${Color_Off} I would like to configure a new server and clients from scratch.

-----------------------------------

${BWhite}2 = Quick Setup:${Color_Off} You will only be asked to specify public server IP.${Color_Off}

-----------------------------------

${BWhite}3 = Clients only:${Color_Off} I just need to generate some client configs and add those to an existing server.${Color_Off}

-----------------------------------

${BWhite}4 = Firewall:${Color_Off} I just need commands to configure IPTABLEs/firewalld.

----------------------------------"

read -r -p "Option #: " scope_of_script

case "$scope_of_script" in
"1")
  sudo bash "$my_wgl_folder"/Scripts/deploy_new_server.sh
  ;;
"2")
  sudo bash "$my_wgl_folder"/Scripts/quick_setup.sh
  ;;
"3")
  sudo bash "$my_wgl_folder"/Scripts/client_config.sh
  ;;
"4")
  sudo bash "$my_wgl_folder"/Scripts/setup_iptables.sh
  ;;
*)
  printf %b\\n "${BRed}Sorry, wrong choise. Rerun the script and try again${Color_Off}"
  ;;
esac
