#!/bin/bash

add_proxies() {
	export http_proxy="http://proxy-iind.intel.com:911"
	export https_proxy="http://proxy-iind.intel.com:912"
	export ftp_proxy="http://proxy-iind.intel.com:911"
	export socks_proxy="http://proxy-iind.intel.com:1080"
	export no_proxy="intel.com,.intel.com,10.0.0.0/8,192.168.0.0/16,localhost,.local,127.0.0.0/8,134.134.0.0/16"
	export DEBIAN_FRONTEND=noninteractive
}
check_docker_proxy() {

  if test -f "/etc/systemd/system/docker.service.d/http-proxy.conf"; then
    echo "http-proxy.conf already exists."
  else 
    sudo mkdir -p /etc/systemd/system/docker.service.d/
    echo "
    [Service] 
    Environment=\"HTTP_PROXY=http://proxy-chain.intel.com:911/\" 
    Environment=\"HTTPS_PROXY=http://proxy-chain.intel.com:911/\" 
    Environment=\"FTP_PROXY=http://proxy-chain.intel.com:911/\" 
    #ExecStart= 
    #ExecStart=/usr/bin/dockerd -H fd:// --dns 10.248.2.1 --dns 10.22.224.196 --dns 10.3.86.116 
    " | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
  fi

  if test -f "/etc/docker/daemon.json"; then
    echo "daemon.json already exists."
  else 
    echo "
    { 
        \"dns\": [\"10.248.2.1\", \"10.22.224.196\", \"10.3.86.116\"] 
    }
    " |sudo tee /etc/docker/daemon.json
  fi

  cd

  if test -f ".docker/config.json"; then
    echo "docker config.json already exists."
  else 
    sudo mkdir .docker
    cd .docker
    sudo touch config.json
    echo "
    {
    \"proxies\":
    {
      \"default\":
      {
        \"httpProxy\": \"http://proxy-chain.intel.com:911\",
        \"httpsProxy\": \"http://proxy-chain.intel.com:912\",
        \"noProxy\":\".intel.com,10.0.0.0/8,192.168.0.0/16,localhost,127.0.0.0/8,134.134.0.0/16,172.16.0.0/12\"
      }
    }
    }
    " | sudo tee config.json
  fi
    echo "Starting Docker Daemon and restarting docker."
    sudo systemctl daemon-reload
    sudo systemctl restart docker
}

uninstall_docker() {
	sudo apt-get remove docker docker-engine docker.io containerd runci
	sudo rm -rf /etc/systemd/system/docker.service.d
	sudo rm -rf ~/.docker
	sudo rm /etc/docker/daemon.json

}



check_docker_installation() {
  if [[ $(which docker) && $(docker --version) ]]; then
    echo $(docker --version)
  else
    apt update
    apt install -y ca-certificates curl gnupg lsb-release
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt  install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin build-essential make
    echo "Installation complete"
    echo $(docker --version)

  fi
  check_docker_proxy
}

git_add_sshkey() {
  ssh-add ~/.ssh/id_rsa
  echo $auth_token | tee mytoken.txt
  gh auth login --with-token < ./mytoken.txt
  gh ssh-key add ~/.ssh/id_rsa.pub
  echo " please provide authorization for ssh key and type "yes" to proceed"
  read user_option
  if [ $user_option != "yes" ]; then 
	exit
  fi

}
git_sshkey_gen() {
  if test -f "$HOME/.ssh/id_rsa" ; then
    echo "SSH key exists."
  else
    echo "SSH Key do not exist, creating ...."
    echo "Enter Git auth token."
    read auth_token
    echo "Enter Git username"
    read user_name
    echo "Enter email"
    read email
    git config --global user.name $user_name
    git config --global user.email $email
    git config --global credential.helper 'store --file ~/.git-credentials'
    echo "https://"$user_name":"$auth_token"@github.com" | tee ~/.git-credentials
    ssh-keygen -t ed25519 -C $email -f ~/.ssh/id_rsa -q -P ""
    eval "$(ssh-agent -s)"
    git_add_sshkey 
  fi
}

clone_repo() {
  check_docker_installation
  sudo apt install -y git gh repo
  git_sshkey_gen
  mkdir linuxpc_test && cd linuxpc_test
  repo init -u https://github.com/intel-innersource/os.linux.bigbang.manifest --no-clone-bundle
  repo sync --no-clone-bundle
}
#sudo su
add_proxies
uninstall_docker
check_docker_installation
clone_repo
