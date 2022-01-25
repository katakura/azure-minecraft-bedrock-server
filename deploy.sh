#!/bin/bash

####################################
### PLEASE CHANGE THIS VARIABLES ###
####################################
LOCATION='japaneast'
RGNAME='minecraft-bedlock-server-rg2'
ADMINNAME='beadmin'
ADMINPASS=''
MYIP=''
####################################

BASENAME='beserver'
# STORAGESKU='Premium_LRS'
# STORAGEKIND='BlockBlobStorage'
# VMSIZE='Standard_D2s_v3'
STORAGESKU='Standard_LRS'
STORAGEKIND='StorageV2'
VMSIZE='Standard_b1s'

if [ ! ${ADMINPASS} ]; then
    echo -n "${ADMINNAME} password: "
    read -s ADMINPASS
    echo
fi

# get my ip address
if [ ! ${MYIP} ]; then
    MYIP=$(curl -s https://ifconfig.me)
    echo "Your IP address is \"${MYIP}\""
fi

# setup container-linux-config-transpiler
CT="./tmp/ct"
mkdir -p $(dirname ${CT})
if [ ! -f ${CT} ]; then
    CT_VER=v0.9.0
    ARCH=x86_64
    OS=unknown-linux-gnu # Linux
    DOWNLOAD_URL=https://github.com/coreos/container-linux-config-transpiler/releases/download
    curl -s -L ${DOWNLOAD_URL}/${CT_VER}/ct-${CT_VER}-${ARCH}-${OS} -o ${CT}
    chmod u+x ${CT}
fi

# exec container-linux-config-transpiler
if [ -f ./config.yml ]; then
    cat ./config.yml | ${CT} --platform=azure | jq >./config.json
fi

# deploy for azure
az group create --resource-group ${RGNAME} --location ${LOCATION} --output table

az deployment group create --resource-group ${RGNAME} \
    --template-file ./deploy.bicep \
    --output table \
    --parameters adminUsername=${ADMINNAME} \
    adminPassword=${ADMINPASS} \
    myIp=${MYIP} \
    baseName=${BASENAME} \
    storageSku=${STORAGESKU} \
    storageKind=${STORAGEKIND} \
    vmSize=${VMSIZE} \
    customData=$(cat ./config.json | base64 -w0)

az network public-ip show --resource-group ${RGNAME} --name ip-${BASENAME} --query 'ipAddress' --output table

exit 0
