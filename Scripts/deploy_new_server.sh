#!/usr/bin/env bash

check_root() {
  if [ "$EUID" -ne 0 ]; then
    printf %b\\n "Please run the script as root."
    exit 1
  fi
}

printf %s\\n "+--------------------------------------------+"
clear_screen() {
  printf '\e[2J\e[H'
}

source_variables() {
  # Default working directory of the script.
  ## Requirements: Cloning the entire repository.
  my_wgl_folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. >/dev/null 2>&1 && pwd)"
  # A simple check if the entire repo was cloned.
  ## If not, working directory is a directory of the currently running script.
  check_for_full_clone="$my_wgl_folder/configure-wireguard.sh"
  if [ ! -f "$check_for_full_clone" ]; then
    my_wgl_folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
  else
    source "$my_wgl_folder"/doc/functions.sh
    # Setting the colours function
    colours
  fi

  # Create a file with shared variables between the scripts
  printf %b\\n "#!/usr/bin/env bash" >"$my_wgl_folder"/shared_vars.sh
}

create_needed_dirs() {
  ######################## Pre-checks ##############################
  # Check if a directory /keys/ exists, if not, it will be made
  check_for_keys_directory=$("$my_wgl_folder"/keys)
  if [ ! -d "$check_for_keys_directory" ]; then
    mkdir -p "$my_wgl_folder"/keys
  fi

  # Check if a directory /client_configs/ exists, if not, it will be made
  check_for_clients_directory=$("$my_wgl_folder"/client_configs)

  if [ ! -d "$check_for_clients_directory" ]; then
    mkdir -p "$my_wgl_folder"/client_configs
  fi
  ##################### Pre-checks finished #########################
}

ask_to_proceed() {
  read -n 1 -s -r -p "
Review the above. 
Press any key to continue 
Press r/R to try again
Press e/E to exit
" your_choice
}

generate_server_config() {

  clear_screen
  # Determine the public IP of the host.
  check_pub_ip=$(curl -s https://checkip.amazonaws.com)

  printf %b\\n "This script will take you through the steps needed to deploy a new server
and configure some clients."

  if [ -f "$check_for_full_clone" ]; then
    printf %b\\n "\n First, let's check if wireguard is installed..."

    ############## Determine OS Type ##############
    # see /doc/functions.sh for more info
    ###############################################
    determine_os
    check_wg_installation
    ############### FINISHED CHECKING OS AND OFFER TO INSTALL WIREGUARD ###############
  fi

  # Private address could be any address within RFC 1918,
  # usually the first useable address in a /24 range.
  # This however is completely up to you.
  printf %b\\n "\n ${BW}Step 1)${Off} ${IW}Please specify the private address of the WireGuard server.${Off}"
  read -r -p "Address: " server_private_range

  clear_screen

  # This would be a UDP port the WireGuard server would listen on.
  printf %b\\n "\n+--------------------------------------------+
${BW}Server private address = ${BR}$server_private_range${Off}
+--------------------------------------------+
\n${BW}Step 2)${Off} ${IW}Please specify listen port of the server.${Off}\n"
  read -r -p "Listen port: " server_listen_port

  clear_screen

  # Public IP address of the server hosting the WireGuard server
  printf %b\\n "\n+--------------------------------------------+
${BW}Server private address = ${BR}$server_private_range${Off}
${BW}Server listen port = ${BR}$server_listen_port${Off}
+--------------------------------------------+
\n${BW}Step 3)${Off} ${IW}The public IP address of this machine is $check_pub_ip. 
Is this the address you would like to use? ${Off}
\n${BW}1 = yes, 2 = no${Off}"
  read -r -p "Choice: " public_address

  printf %s\\n "+--------------------------------------------+"

  if [ "$public_address" = 1 ]; then
    server_public_address="$check_pub_ip"
  elif [ "$public_address" = 2 ]; then
    printf %b\\n "\n${IW}Please specify the public address of the server.${Off}"
    read -r -p "Public IP: " server_public_address
    printf %s\\n "+--------------------------------------------+"
  fi

  clear_screen

  # Internet facing iface of the server hosting the WireGuard server
  printf %b\\n "\n+--------------------------------------------+
${BW}Server private address = ${BR}$server_private_range${Off}
${BW}Server listen port = ${BR}$server_listen_port${Off}
${BW}Server public address = ${BR}$server_public_address${Off}
+--------------------------------------------+"
  printf %b\\n "\n${BW}Step 4)${IW} Please also provide the internet facing interface of the server. 
${BW}Example: ${BR}eth0${Off}"
  if [ "$distro" != "" ] && [ "$distro" != "freebsd" ]; then
    printf %b\\n "\n Available interfaces are:
+--------------------+
$(ip -br a | awk '{print $1}')
+--------------------+"
  else
    printf %b\\n "\n Available interfaces are:
+--------------------+
$(ifconfig -l)
+--------------------+"
  fi

  read -r -p "Interface: " local_interface

  clear_screen

  printf %b\\n "\n+--------------------------------------------+
${BW}Server private address = ${BR}$server_private_range${Off}
${BW}Server listen port = ${BR}$server_listen_port${Off}
${BW}Server public address = ${BR}$server_public_address${Off}
${BW}WAN interface = ${BR}$local_interface${Off}
+--------------------------------------------+ \n"

  ask_to_proceed

  case "$your_choice" in
    [Rr]*)
      sudo bash "$my_wgl_folder"/Scripts/deploy_new_server.sh
      ;;
    [Ee]*)
      exit
      ;;
    *)
      clear_screen
      ;;
  esac

  printf %b\\n "\n+--------------------------------------------+
${BW}Server private address = ${BR}$server_private_range${Off}
${BW}Server listen port = ${BR}$server_listen_port${Off}
${BW}Server public address = ${BR}$server_public_address${Off}
${BW}WAN interface = ${BR}$local_interface${Off}
+--------------------------------------------+"

  # This would be the private and public keys of the server.
  # If you are using this script, chances are those have not yet been generated yet.

  printf %b\\n "\n${IW}Do you need to generate server keys?${Off} 
(If you have not yet configured the server, the probably yes).

${BW}1 = yes, 2 = no${Off}\n"

  read -r -p "Choice: " generate_server_key
  printf %s\\n "+--------------------------------------------+"

  if [ "$generate_server_key" = 1 ]; then
    wg genkey | tee "$my_wgl_folder"/keys/ServerPrivatekey | wg pubkey >"$my_wgl_folder"/keys/ServerPublickey
    chmod 600 "$my_wgl_folder"/keys/ServerPrivatekey && chmod 600 "$my_wgl_folder"/keys/ServerPublickey

  # The else statement assumes the user already has server keys,
  # hence the option to generate them was not chosen.
  # For the script to generate a server config, the user is asked
  # to provide public/private key pair for the server.

  else
    printf %b\\n "\n${IW}Specify server private key.${Off}\n"
    read -r -p "Server private key: " server_private_key
    printf %b\\n "$server_private_key" >"$my_wgl_folder"/keys/ServerPrivatekey
    printf %s\\n "+--------------------------------------------+"
    printf %b\\n "\n${IW}Specify server public key.${Off}\n"
    read -r -p "Server public key: " server_public_key
    printf %b\\n "$server_public_key" >"$my_wgl_folder"/keys/ServerPublickey
    chmod 600 "$my_wgl_folder"/keys/ServerPrivatekey && chmod 600 "$my_wgl_folder"/keys/ServerPrivatekey
    printf %s\\n "+--------------------------------------------+"

  fi

  sever_private_key_output=$(cat "$my_wgl_folder"/keys/ServerPrivatekey)
  sever_public_key_output=$(cat "$my_wgl_folder"/keys/ServerPublickey)

  printf %b\\n "\n${IW}Specify wireguard server interface name 
(will be the same as config name, without .conf)${Off}\n"

  read -r -p "WireGuard Interface: " wg_serv_iface

  clear_screen

  printf %b\\n "\n+--------------------------------------------+
${BW}Server private address = ${BR}$server_private_range${Off}
${BW}Server listen port = ${BR}$server_listen_port${Off}
${BW}Server public address = ${BR}$server_public_address${Off}
${BW}WAN interface = ${BR}$local_interface${Off}
${BW}WireGuard interface = ${BR}$wg_serv_iface${Off}
+--------------------------------------------+\n"

  {
    printf %b\\n "server_private_range=$server_private_range"
    printf %b\\n "server_listen_port=$server_listen_port"
    printf %b\\n "server_public_address=$server_public_address"
    printf %b\\n "local_interface=$local_interface"
    printf %b\\n "wg_serv_iface=$wg_serv_iface"
  } >>"$my_wgl_folder"/shared_vars.sh

  printf %b\\n "\n Generating server config file...."

  sleep 2

  if [ "$distro" != "" ] && [ "$distro" = "freebsd" ]; then
    # We wont use iptables in server config on FreeBSD.
    # Everythig will be handled by IPFW.
    new_server_config=$(printf %b\\n "
[Interface]
Address = $server_private_range/32
SaveConfig = true
ListenPort = $server_listen_port
PrivateKey = $sever_private_key_output
  ")

  else

    new_server_config=$(printf %b\\n "
[Interface]
Address = $server_private_range/32
SaveConfig = true
PostUp = iptables -A FORWARD -i $wg_serv_iface -j ACCEPT; iptables -t nat -A POSTROUTING -o $local_interface -j MASQUERADE; ip6tables -A FORWARD -i $wg_serv_iface -j ACCEPT; ip6tables -t nat -A POSTROUTING -o $local_interface -j MASQUERADE
PostDown = iptables -D FORWARD -i $wg_serv_iface -j ACCEPT; iptables -t nat -D POSTROUTING -o $local_interface -j MASQUERADE; ip6tables -D FORWARD -i $wg_serv_iface -j ACCEPT; ip6tables -t nat -D POSTROUTING -o $local_interface -j MASQUERADE
ListenPort = $server_listen_port
PrivateKey = $sever_private_key_output
  ")

  fi

  printf %b\\n "$new_server_config" >"$my_wgl_folder"/"$wg_serv_iface".conf
  chmod 600 "$my_wgl_folder"/"$wg_serv_iface".conf

  printf %b\\n "Server config has been written to a file $my_wgl_folder/$wg_serv_iface.conf"
  printf %s\\n "+--------------------------------------------+"

  sleep 2

  printf %b\\n "\n ${IW}Save config to /etc/wireguard/?${Off}\n
NOTE: ${UW}Choosing to save the config under the same file-name as
an existing config will ${BR}overrite it.${Off}\n
This script will check if a config file with the same name already
exists. It will back the existing config up before overriting it.
+--------------------------------------------+\n
Save config: ${BW}1 = yes, 2 = no${Off}\n"

  check_for_existing_config="/etc/wireguard/$wg_serv_iface.conf"

  read -r -p "Choice: " save_server_config

  # The if statement checks whether a config with the same filename already exists.
  # If it does, the falue will always be less than zero, hence it needs to be backed up.
  if [ "$save_server_config" = 1 ] && [ -f "$check_for_existing_config" ]; then
    printf %b\\n "
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    Found existing config file with the same name. 
    Backing up to /etc/wireguard/$wg_serv_iface.conf.bak
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    sleep 2
    mv /etc/wireguard/"$wg_serv_iface".conf /etc/wireguard/"$wg_serv_iface".conf.bak
    sleep 1
    printf %b\\n "$new_server_config" >/etc/wireguard/"$wg_serv_iface".conf
    clear_screen
    printf %b\\n "\nCongrats! Server config is ready and saved to \n/etc/wireguard/$wg_serv_iface.conf... The config is shown below."
  elif [ "$save_server_config" = 1 ] && [ ! -f "$check_for_existing_config" ]; then
    # Make /etc/wireguard if it does not exist yet
    # Example is FreeBSD - /etc/wireguard is not automatically created
    # after installing WG.
    mkdir -p /etc/wireguard
    printf %b\\n "$new_server_config" >/etc/wireguard/"$wg_serv_iface".conf
    clear_screen
    printf %b\\n "\nCongrats! Server config is ready and saved to \n/etc/wireguard/$wg_serv_iface.conf... The config is shown below."
  elif [ "$save_server_config" = 2 ]; then
    clear_screen
    printf %b\\n "\nUnderstood! Server config copy \nis located in $my_wgl_folder/$wg_serv_iface.conf.\nThe config is shown below."
  fi

  printf %b\\n "\n\n${IY}$new_server_config${Off}\n" | sed -E 's/PrivateKey = .*/PrivateKey = Hidden/g'

  printf %s\\n "+--------------------------------------------+"
}

generate_client_configs() {
  printf %b\\n "\n${IW}Configure clients?${Off}
${BW}1=yes, 2=no${Off}"

  read -r -p "Choice: " client_config_answer
  printf %s\\n "+--------------------------------------------+"

  if [ "$client_config_answer" = 1 ]; then
    clear_screen
    printf %b\\n "\n${IW}How many clients would you like to configure?${Off}\n"
    read -r -p "Number of clients: " number_of_clients

    printf %s\\n "+--------------------------------------------+"

    printf %b\\n "\n${IW}Specify the DNS server your clients will use.${Off}\n"
    # This would usually be a public DNS server, for example 1.1.1.1,
    # 8.8.8.8, etc.
    read -r -p "DNS server: " client_dns
    clear_screen
    printf %b\\n "\nNext steps will ask to provide \nprivate address and a name for each client, one at a time.\n"
    printf %s\\n "+--------------------------------------------+"

    # Private address would be within the RFC 1918 range of the server.
    # For example if the server IP is 10.10.10.1/24, the first client
    # would usually have an IP of 10.10.10.2; though this can be any
    # address as long as it's within the range specified for the server.
    for i in $(seq 1 "$number_of_clients"); do
      printf %b\\n "\n${IW}Private address of client # $i (do NOT include /32):${Off}\n"
      read -r -p "Client $i IP: " client_private_address_["$i"]
      # Client name can be anything, mainly to easily identify the device
      # to be used. Some exampmles are:
      # Tom_iPhone
      # Wendy_laptop

      printf %s\\n "+--------------------------------------------+"

      printf %b\\n "\n${IW}Provide the name of the client # $i ${Off}\n"
      read -r -p "Client $i name: " client_name_["$i"]

      printf %s\\n "+--------------------------------------------+"

      wg genkey | tee "$my_wgl_folder"/keys/"${client_name_["$i"]}"Privatekey | wg pubkey >"$my_wgl_folder"/keys/"${client_name_["$i"]}"Publickey

      chmod 600 "$my_wgl_folder"/keys/"${client_name_["$i"]}"Privatekey
      chmod 600 "$my_wgl_folder"/keys/"${client_name_["$i"]}"Publickey

      client_private_key_["$i"]="$(cat "$my_wgl_folder"/keys/"${client_name_["$i"]}"Privatekey)"
      client_public_key_["$i"]="$(cat "$my_wgl_folder"/keys/"${client_name_["$i"]}"Publickey)"

      printf %b\\n "\n[Interface]
Address = ${client_private_address_["$i"]}
PrivateKey = ${client_private_key_["$i"]}
DNS = $client_dns\n
[Peer]
PublicKey = $sever_public_key_output
Endpoint = $server_public_address:$server_listen_port
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 21" >"$my_wgl_folder"/client_configs/"${client_name_["$i"]}".conf
      clear_screen
    done
    printf %b\\n "\nAwesome!\nClient config files were saved to ${IW}$my_wgl_folder/client_configs/${Off}"
  else
    printf %s\\n "+--------------------------------------------+"
    printf %b\\n "${IW}Before ending this script,\nwould you like to setup firewall rules for the new server? (recommended)${Off}\n
  ${BW}1 = yes, 2 = no${Off}\n"
    read -r -p "Choice: " iptables_setup
    if [ "$iptables_setup" = 1 ]; then
      sudo bash "$my_wgl_folder"/Scripts/setup_iptables.sh
    else
      printf %b\\n "Sounds good. Ending the scritp..."
      exit
    fi
  fi
  printf %b\\n "\n${IW}If you've got qrencode installed, the script can generate QR codes for
the client configs.\n\n Would you like to have QR codes generated?
\n1= yes, 2 = no${Off}"

  read -r -p "Choice: " generate_qr_code

  if [ "$generate_qr_code" = 1 ]; then
    for q in $(seq 1 "$number_of_clients"); do
      printf %b\\n "${BR}${client_name_[$q]}${Off}\n"
      qrencode -t ansiutf8 <"$my_wgl_folder"/client_configs/"${client_name_["$q"]}".conf
      printf %s\\n "+--------------------------------------------+"
    done
  elif [ "$generate_qr_code" = 2 ]; then
    printf %b\\n "\nAlright.. Moving on!\n+--------------------------------------------+"
  else
    printf %b\\n "Sorry, wrong choice! Moving on with the script."
  fi

  printf %b\\n "\n${IW}Would you like to add client info to the server config now?${Off}
\n${BW}1 = yes, 2 = no${Off}"
  read -r -p "Choice: " configure_server_with_clients

  # If you chose to add client info to the server config AND to save the server config
  # to /etc/wireguard/, then the script will add the clients to that config
  if [ "$configure_server_with_clients" = 1 ]; then
    for a in $(seq 1 "$number_of_clients"); do
      printf %b\\n "\n[Peer]
PublicKey = ${client_public_key_["$a"]}
AllowedIPs = ${client_private_address_["$a"]}/32\n" >>/etc/wireguard/"$wg_serv_iface".conf
    done
  elif [ "$configure_server_with_clients" = 2 ]; then
    printf %b\\n "\nAlright, you may add the following to a server config file to setup clients.
\n-----------------\n"
    for d in $(seq 1 "$number_of_clients"); do
      printf %b\\n "\n${IY}[Peer]
PublicKey = ${client_public_key_["$d"]}
AllowedIPs = ${client_private_address_["$d"]}/32${Off}\n"
    done
  fi

  printf %b\\n "-----------------"
}

enable_wireguard_iface() {
  # This assumes the WireGuard is already installed on the server.
  # The script checks is there is config in /etc/wireguard/, if there is one,
  # the value of the grep will be greater than or equal to 1, means it can be used
  # to bring up the WireGuard tunnel interface.
  printf %b\\n "${IW}Almost done!
Would you like to bring WireGuard interface up and to enable the service on boot?${Off}
\n${BW}1 = yes, 2 = no${Off}\n"

  read -r -p "Choice: " enable_on_boot
  clear_screen
  if [ "$enable_on_boot" = 1 ]; then
    # If current OS is FreeBSD - we wont use systemd as we would've for supported linux distros.
    freebsd_os=$(uname -a | awk '{print $1}' | grep -i -c FreeBSD)
    if [ "$freebsd_os" -gt 0 ]; then
      printf %b\\n "\n${IY}chown -v root:root /etc/wireguard/$wg_serv_iface.conf
chmod -v 600 /etc/wireguard/$wg_serv_iface.conf
sysrc wireguard_enable=\"YES\"
sysrc wireguard_interfaces=\"$wg_serv_iface\"
service wireguard start${Off}\n"

      ask_to_proceed

      case "$your_choice" in
        [Rr]*)
          sudo bash "$my_wgl_folder"/Scripts/deploy_new_server.sh
          ;;
        [Ee]*)
          exit
          ;;
        *)
          chown -v root:root /etc/wireguard/"$wg_serv_iface".conf
          chmod -v 600 /etc/wireguard/"$wg_serv_iface".conf
          sysrc wireguard_enable="YES"
          sysrc wireguard_interfaces="$wg_serv_iface"
          service wireguard start
          ;;
      esac

    else
      printf %b\\n "\n${IY}chown -v root:root /etc/wireguard/$wg_serv_iface.conf
  chmod -v 600 /etc/wireguard/$wg_serv_iface.conf
  wg-quick up $wg_serv_iface
  systemctl enable wg-quick@$wg_serv_iface.service${Off}\n"

      ask_to_proceed

      case "$your_choice" in
        [Rr]*)
          sudo bash "$my_wgl_folder"/Scripts/deploy_new_server.sh
          ;;
        [Ee]*)
          exit
          ;;
        *)
          chown -v root:root /etc/wireguard/"$wg_serv_iface".conf
          chmod -v 600 /etc/wireguard/"$wg_serv_iface".conf
          wg-quick up "$wg_serv_iface"
          systemctl enable wg-quick@"$wg_serv_iface".service
          ;;
      esac
    fi
  elif [ "$enable_on_boot" = 2 ]; then
    printf %b\\n "\n${IW} To manually enable the service and bring tunnel interface up,
  the following commands can be used:${Off}"
    if [ "$freebsd_os" = 0 ]; then
      printf %b\\n "\n${IY}chown -v root:root /etc/wireguard/$wg_serv_iface.conf
chmod -v 600 /etc/wireguard/$wg_serv_iface.conf
wg-quick up $wg_serv_iface
systemctl enable wg-quick@$wg_serv_iface.service${Off}"
    else
      printf %b\\n "\n${IY}chown -v root:root /etc/wireguard/$wg_serv_iface.conf
chmod -v 600 /etc/wireguard/$wg_serv_iface.conf
sysrc wireguard_enable=\"YES\"
sysrc wireguard_interfaces=$wg_serv_iface
service wireguard start${Off}"
    fi
  fi
}

setup_firewall() {
  printf %b\\n "\n${IW}Before ending this script, would you like to setup firewall rules for the new server? (recommended)${Off}
\n${BW}1 = yes, 2 = no${Off}\n"

  read -r -p "Choice: " iptables_setup
  if [ "$iptables_setup" = 1 ]; then
    sudo bash "$my_wgl_folder"/Scripts/setup_iptables.sh
  else
    printf %b\\n "Sounds good. Ending the script..."
  fi
  exit
}

main() {
  check_root
  source_variables
  create_needed_dirs
  generate_server_config
  generate_client_configs
  enable_wireguard_iface
  setup_firewall
}

main
