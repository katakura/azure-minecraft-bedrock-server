# azure-minecraft-bedrock-server

## introduction

This is a template file for deploying a Minecraft Bedrock server in Azure very cheaply.

The cheapest virtual machine (1 core, 1GB) costs about $10~/month.

Use the lightweight Flatcar for our virtual machines.
The Minecraft server uses the very popular itzg/minecraft-server container image available on DockerHub.

[https://hub.docker.com/r/itzg/minecraft-server](https://hub.docker.com/r/itzg/minecraft-server)

For the persistent area, use Azure storage in the virtual network, connected via NFS(v3).

## direct (and simple) deploy

```bash
az group create -g test-beserver-rg -l eastus
az deployment group create -g test-beserver-rg -f ./deploy.bicep -p myIp=<your_client_ip_address> adminPassword=<password>
```

## script deploy

1. edit config.yml file
2. edit deploy.sh file
3. run deploy.sh under linux client machine

```bash
./deploy.sh
```

## FAQ

### The Minecraft container does not start in the VM immediately after deployment

Since the orchestration is appropriate (docker commands are run from shell), it may not start right after VM deployment if the timing is bad.

In that case, try restarting the VM once.

I'd like to use Docker compose or something similar, but it's not implemented yet. (Issue, PR regards)

### How do I connect from the Minecraft app?

Please specify the Public IP Address assigned to the VM in the application.

The port number is 19132.

### I want to change the server settings or set the game rules while it is running.

After logging in to the VM, connect to the container instance with docker attach, and then execute the command.

The last step is to detach the session with ^P ^Q.

### I'd like to know a few more things about you

The documentation will be expanded. I'll also write a Blog (but in Japanese).
