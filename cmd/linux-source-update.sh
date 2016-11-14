#!/bin/bash

echo "****************************begin**************************************"
echo "make a copy..."
mv /etc/apt/sources.list /etc/apt/sources.list.bak

echo "remove old sources.list..."
rm /etc/apt/sources.list

echo "creating new sources.list..."
touch /etc/apt/sources.list
echo "deb http://mirrors.aliyun.com/ubuntu/ trusty main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://mirrors.aliyun.com/ubuntu/ trusty-security main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://mirrors.aliyun.com/ubuntu/ trusty-updates main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://mirrors.aliyun.com/ubuntu/ trusty-proposed main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://mirrors.aliyun.com/ubuntu/ trusty-backports main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb-src http://mirrors.aliyun.com/ubuntu/ trusty main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb-src http://mirrors.aliyun.com/ubuntu/ trusty-security main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb-src http://mirrors.aliyun.com/ubuntu/ trusty-updates main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb-src http://mirrors.aliyun.com/ubuntu/ trusty-proposed main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb-src http://mirrors.aliyun.com/ubuntu/ trusty-backports main restricted universe multiverse" >> /etc/apt/sources.list
echo " create sources.list success"

echo "update package..."
apt-get update

echo "*****************************done************************************"
