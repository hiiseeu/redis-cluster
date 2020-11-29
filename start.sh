#/bin/bash

#*********************************************************
# Author        : yuxiao
# Email         : iseeyou@hiseeu.cn
# Description   : redis集群一键脚本
# *******************************************************

echo "初始化redis集群配置文件"
echo "获取本机ip地址"
ip=`ifconfig en1|awk 'NR==5 {print  $2}'`

echo "创建docker-compose.yml 文件"
cat << EOF > docker-compose.yml
version: "3"
services:
EOF

if [ ! -d "./conf" ];then
    mkdir  ./conf
fi

echo "循环创建redis.conf配置文件"
for i in 0 1 2 3 4 5 6 7 8 9
do
cat << EOF > conf/redis-638${i}.conf
port 638${i}

#enable cluster mode
cluster-enabled yes

#ms
cluster-node-timeout 15000

#集群内配置文件
cluster-config-file "nodes-638${i}.conf"

#data目录
dir /data/redis/

appendonly yes
#log
logfile /var/log/redis/638${i}.log

#改为docker虚拟网卡ip
cluster-announce-ip  ${ip}
cluster-announce-port 638${i}
cluster-announce-bus-port 1638${i}

EOF
done

ips=''
echo "循环编辑docker-compose.yml文件"
for num in 0 1 2 3 4 5 6 7 8 9
do
echo "    redis-cluster-638${num}:" >> docker-compose.yml
echo "        image: redis:5.0.5-alpine" >> docker-compose.yml
echo "        container_name: node-8${num}" >> docker-compose.yml
echo "        networks:" >> docker-compose.yml
echo "            cluster-net:" >> docker-compose.yml
echo "                ipv4_address: 172.16.238.1${num}" >> docker-compose.yml
echo "        ports:" >> docker-compose.yml
echo "            - \"638${num}:638${num}\"" >> docker-compose.yml
echo "            - \"1638${num}:1638${num}\"" >> docker-compose.yml
echo "        volumes:" >> docker-compose.yml
echo "            - ./conf/redis-638${num}.conf:/usr/local/etc/redis/redis.conf" >> docker-compose.yml
echo "            - ./log:/var/log/redis" >> docker-compose.yml
echo "            - ./data/638${num}:/data/redis" >> docker-compose.yml
echo "        command: sh -c \"redis-server /usr/local/etc/redis/redis.conf\"" >> docker-compose.yml
echo "        environment:" >> docker-compose.yml
echo "            # 设置时区为上海，否则时间会有问题" >> docker-compose.yml
echo "            - TZ=Asia/Shanghai" >> docker-compose.yml
ips="${ips}172.16.238.1${num}:638${num} "
done

echo "networks:" >> docker-compose.yml
echo "    # 创建集群网络，在容器之间通信" >> docker-compose.yml
echo "    cluster-net:" >> docker-compose.yml
echo "        ipam:" >> docker-compose.yml
echo "            config:" >> docker-compose.yml
echo "                - subnet: 172.16.238.0/24\n" >> docker-compose.yml

echo "启动redis集群"
docker-compose up -d
wait
sleep 4
echo "配置redis集群"
docker exec -it node-80 redis-cli -p 6380 --cluster create ${ips} --cluster-replicas 1
wait
echo "启动redis集群成功"
