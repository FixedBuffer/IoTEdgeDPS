#!/bin/bash

generateDerivedKey(){
  KEY=$2
  REG_ID=$1
  keybytes=$(echo $KEY | base64 --decode | xxd -p -u -c 1000)
  echo -n $REG_ID | openssl sha256 -mac HMAC -macopt hexkey:$keybytes -binary | base64
}

startEdgeRuntime(){
echo "***Configuring and Starting IoT Edge Runtime***"
DEVICE=$(cat /proc/sys/kernel/hostname)
echo "Device name: $DEVICE"


IP=$(ifconfig eth0 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')

echo export IOTEDGE_HOST=http://$IP:15580 >> ~/.bashrc


cat <<EOF > /etc/iotedge/config.yaml
provisioning:
  source: "dps"  
  global_endpoint: "https://global.azure-devices-provisioning.net"
  scope_id: $SCOPE_ID 
  attestation:
    method: "symmetric_key"
    symmetric_key: "$(generateDerivedKey $DEVICE $SYMMETRIC_KEY)"
    registration_id: "$DEVICE"  
  dynamic_reprovisioning: true
agent:
  name: "edgeAgent"
  type: "docker"
  env: {}
  config:
    image: "mcr.microsoft.com/azureiotedge-agent:1.0"
    auth: {}
hostname: $DEVICE
connect:
  management_uri: "http://$IP:15580"
  workload_uri: "http://$IP:15581"
listen:
  management_uri: "http://$IP:15580"
  workload_uri: "http://$IP:15581"
homedir: "/var/lib/iotedge"
moby_runtime:
  docker_uri: "/var/run/docker.sock"
  network: "azure-iot-edge"
EOF

cat /etc/iotedge/config.yaml

iotedged -c /etc/iotedge/config.yaml 

}

echo "***Starting Docker in Docker***"
#remove docker.pid if it exists to allow Docker to restart if the container was previously stopped
if [ -f /var/run/docker.pid ]; then
    echo "Stale docker.pid found in /var/run/docker.pid, removing..."
    rm /var/run/docker.pid
fi

while (! docker stats --no-stream ); do
  # Docker takes a few seconds to initialize
  dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2375 &
  echo "Waiting for Docker to launch..."
  sleep 1
done

startEdgeRuntime