#!/usr/bin/env bash

# Variáveis de ambiente
export CNI_PLUGINS_VERSION="1.3.0"
export KUBEADM_VERSION="1.26"

# Ativando módulos do kernel necessários ao containerd
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Paramêtros do sysctl necessários para instalação do containerd
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Aplicando paramêtros do sysctl sem reboot
sudo sysctl --system

# Adicionado chave pública oficial do docker:
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Adicionando o repositório do containerd nas fontes do apt:
echo \
          "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
              sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

sudo apt-get -y install containerd.io

# Instalando cni-plugins

curl -fsSLo "/tmp/cni-plugins-linux-amd64-v$CNI_PLUGINS_VERSION.tgz" \
        "https://github.com/containernetworking/plugins/releases/download/v$CNI_PLUGINS_VERSION/cni-plugins-linux-amd64-v$CNI_PLUGINS_VERSION.tgz"
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin "/tmp/cni-plugins-linux-amd64-v$CNI_PLUGINS_VERSION.tgz"

# Configurando o systemd como driver para cgroups
sudo sh -c 'echo "
[plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runc.options]
  SystemdCgroup = true" >> /etc/containerd/config.toml'

# Habilitando cri-plugin
sudo sed -i 's/disabled_plugins/#disabled_plugins/' /etc/containerd/config.toml

# Restartando containerd
sudo systemctl restart containerd

# Adicionando repositório do kubeadm 1.26
sudo apt-get update

# Talvez você já tenha o pacote apt-transport-https; Se sim, você pode ignorá-lo
sudo apt-get install -y apt-transport-https ca-certificates cursudo apt-get install -y apt-transport-https ca-certificates curll
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v$KUBEADM_VERSION/deb/Release.key" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Isso irá sobrescrever qualquer configuração existente em /etc/apt/sources.list.d/kubernetes.list
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$KUBEADM_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubeadm