#!/bin/bash

fmt=`tput setaf 45`
end="\e[0m\n"
err="\e[31m"
scss="\e[32m"

function start () {
# create dirs
cd
mkdir story_binary
cd story_binary
mkdir geth_client
mkdir story_client

# download bins
echo -e "${fmt}\nDownloading binaries${end}" && sleep 1
wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.9.2-ea9f0d2.tar.gz
wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.9.11-2a25df1.tar.gz

# extract bins
echo -e "${fmt}\nExtracting binaries${end}" && sleep 1
tar zxvf story-linux-amd64-0.9.11-2a25df1.tar.gz --strip-components=1 -C story_client
tar zxvf geth-linux-amd64-0.9.2-ea9f0d2.tar.gz --strip-components=1 -C geth_client


# start story client
cd /root/story_binary/story_client
echo -e "${fmt}\nInitializing Story client${end}" && sleep 1
if [ -z "$MONIKER+x" ]; then echo "${err}\nMONIKER is not set${err}" && return; else echo "${fmt}\nMONIKER: $MONIKER ${end}"; fi
./story init --network iliad --moniker $MONIKER
if [ $? -eq 0 ]; then
    echo -e "${fmt}\nStory client initiated${end}" && sleep 1
else
    echo -e "${err}\nStory client initiate error${end}" && return
fi

sudo tee /etc/systemd/system/storyd.service > /dev/null <<EOF
[Unit]
Description=Story Client
After=network-online.target
[Service]
User=root
WorkingDirectory=/root/story_binary/story_client
ExecStart=/root/story_binary/story_client/story run
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable storyd.service
sudo systemctl start storyd
if [ $? -eq 0 ]; then
    echo -e "${fmt}\nStory client started${end}" && sleep 1
else
    echo -e "${err}\nStory client start error${end}" && return
fi

# start geth client
sudo tee /etc/systemd/system/gethd.service > /dev/null <<EOF
[Unit]
Description=Geth Client
After=network-online.target
[Service]
User=root
WorkingDirectory=/root/story_binary/geth_client
ExecStart=/root/story_binary/geth_client/geth --iliad --syncmode full
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable gethd.service
sudo systemctl start gethd
if [ $? -eq 0 ]; then
    echo -e "${fmt}\nGeth client started${end}" && sleep 1
else
    echo -e "${err}\nGeth client start error${end}" && return
fi

echo -e "${scss}\nNode installed${end}" && sleep 1

}

start
