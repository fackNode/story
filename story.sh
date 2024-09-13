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
sudo chmod +x /root/story_binary/story_client/story /root/story_binary/geth_client/geth
mv /root/story_binary/story_client/story /usr/local/bin
mv /root/story_binary/geth_client/geth /usr/local/bin
echo -e "${fmt}\nInitializing Story client${end}" && sleep 1
if [ -z "$MONIKER" ]; then echo "${err}\nMONIKER is not set${err}" && return; else echo "${fmt}\nMONIKER: $MONIKER ${end}"; fi
story init --network iliad --moniker $MONIKER
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
ExecStart=story run
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
ExecStart=geth --iliad --syncmode full
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



echo -e "${fmt}\nInstalling additional dependencies${end}"

sudo apt-get update
sudo apt-get install wget lz4 aria2 pv jq -y

echo -e "${fmt}\nInstalling snapshot${end}" && sleep 1

sudo systemctl stop storyd
sudo systemctl stop gethd

cd $HOME
rm -f Geth_snapshot.lz4
if curl -s --head https://vps7.josephtran.xyz/Story/Geth_snapshot.lz4 | head -n 1 | grep "200" > /dev/null; then
    echo "Snapshot found, downloading..."
    aria2c -x 16 -s 16 https://vps7.josephtran.xyz/Story/Geth_snapshot.lz4 -o Geth_snapshot.lz4
else
    echo -e "${err}\nNo geth snapshot${end}"
    return
fi

rm -f Story_snapshot.lz4
if curl -s --head https://vps7.josephtran.xyz/Story/Story_snapshot.lz4 | head -n 1 | grep "200" > /dev/null; then
    echo "Snapshot found, downloading..."
    aria2c -x 16 -s 16 https://vps7.josephtran.xyz/Story/Story_snapshot.lz4 -o Story_snapshot.lz4
else
    echo -e "${err}\nNo story snapshot${end}"
    return
fi

mv $HOME/.story/story/data/priv_validator_state.json $HOME/.story/priv_validator_state.json.backup

rm -rf ~/.story/story/data
rm -rf ~/.story/geth/iliad/geth/chaindata

sudo mkdir -p /root/.story/story/data
lz4 -d Story_snapshot.lz4 | pv | sudo tar xv -C /root/.story/story/

sudo mkdir -p /root/.story/geth/iliad/geth/chaindata
lz4 -d Geth_snapshot.lz4 | pv | sudo tar xv -C /root/.story/geth/iliad/geth/

mv $HOME/.story/priv_validator_state.json.backup $HOME/.story/story/data/priv_validator_state.json

sudo systemctl start storyd
sudo systemctl start gethd

echo -e "${scss}\nSnapshot installed${end}" && sleep 1

}

start
