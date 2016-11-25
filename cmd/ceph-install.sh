#!/bin/bash

#update package sources,if update slowly,please click http://blog.csdn.net/u010317005/article/details/52953698
#apt-get update

if [ ! -f "/usr/bin/bc" ]; then
 apt-get install bc
fi

#set ceph install path

read -p "input the ceph install path(e.g: /ceph):" path

if [ "${path:0:1}" = "/" ];then
  if [ ! -d ${path} ];then
   # echo "create new path:${path}"
    mkdir -p ${path}
  fi
 # echo "absolute directory:${path}"
else
  pwd=`pwd`
  if [ ! -d "${pwd}/${path}" ];then
  # echo "create new path:${pwd}/${path}"
   mkdir -p ${pwd}/${path}
  fi
  path=${pwd}/${path}
 # echo "path:${path}"
fi


##########get data from df -h#############
df -h | while read line
do
  #for var in $line
  line_path=`echo ${line} | awk -F' ' '{print $6}'`
  line_avail=`echo ${line} | awk -F' ' '{print $4}'`
   if [ "${line_path:0:1}" != "/" ]; then
     continue
   fi

   if [ "${line_path}" = "/" ]; then
      root_avail=${line_avail}
     #echo "root_avail:${root_avail}"
     if [ -f /tmp/tmp_root_avail ];then
       rm /tmp/tmp_root_avail
     fi
     echo ${root_avail} > /tmp/tmp_root_avail
     continue
   fi

  path_length=${#line_path}
  if [ "${path:0:${path_length}}" = "${line_path}" ];then
   # echo "${path} contain path:${line_path}"
    path_avail=${line_avail}
    if [ -f /tmp/tmp_path_avail ];then
      rm /tmp/tmp_path_avail
    fi
    echo ${path_avail} > /tmp/tmp_path_avail
    break
  fi

done

#############get data from temp file###############
if [ -f /tmp/tmp_path_avail ];then
 path_avail=`cat /tmp/tmp_path_avail`
 rm /tmp/tmp_path_avail
fi
if [ -f /tmp/tmp_root_avail ];then
 root_avail=`cat /tmp/tmp_root_avail`
 rm /tmp/tmp_root_avail
fi


###################compute######################
if [ -z ${path_avail} ];then
#   echo "root_avail:${root_avail}"
#   echo "path_avail=${path_avail}"
   path_avail=${root_avail}
fi

echo "${path} avail space is : ${path_avail}"
if [ ${path_avail: -1} != "G" ]; then
   echo -e "${path} have not enough space..\nexit now..."
   exit
fi
let length_real=${#path_avail}-1
real_size=${path_avail:0:${length_real}}
if [ $(echo "${real_size}-11>0" | bc ) = 0 ]; then
   echo "${path} have free space:${real_size}G,CEPH need about 11G free space,exit now...."
   exit
fi

 
ceph_root=${path}
cd ${ceph_root}

###############################################
read -p "input ceph version(default:ceph-0.94.5):" version
if [ -n ${version} ]; then
     version=ceph-0.94.5
fi
###############################################

echo "get CEPH source code..."
if [ ! -f ${version}.tar.gz ]; then
  wget http://download.ceph.com/tarballs/${version}.tar.gz
fi

echo "install dep package..."
apt-get -y install autotools-dev autoconf automake cdbs gcc g++ git libboost1.55-dev libedit-dev libssl-dev libtool libfcgi libfcgi-dev libfuse-dev linux-kernel-headers libcrypto++-dev libcrypto++ libexpat1-dev pkg-config
apt-get -y install libtool cython libsnappy-dev libleveldb-dev libblkid-dev libudev-dev libkeyutils-dev libatomic-ops-dev libaio-dev libgoogle-perftools-dev xfslibs-dev libboost-system1.55-dev libboost1.55-dev libboost-iostreams1.55-dev libboost-thread1.55-dev libboost-random1.55-dev libboost-program-options1.55-dev libldap2-dev



if [ ! -d ${version} ]; then
 echo "release source package..."
 tar zxvf ${version}.tar.gz
fi

echo "change directory to the release code dir..."
cd ${version}
pwd
echo "install CEPH original deps and config env..."
./install-deps.sh
./autogen.sh
./configure #you can add --prefix=/usr/local to configure it to given path,please make sure the path have enough room£¨version 0.94.5,after compiled about 10G output)

echo "compile and install..."
cores=`cat /proc/cpuinfo| grep "physical id"| sort| uniq| wc -l`
make -j${cores} && make install


echo "*********************************************************************************************"


echo "set PYTHONPATH env vaiables,avoid some problem cause by Python...(add a if to test version of python)"

touch ~/.bash_profile
result=`cat ~/.bash_profile | grep "PYTHONPATH"`
[[ ${result}=~"PYTHONPATH" ]] || echo "export PYTHONPATH=$PYTHONPATH:/usr/local/lib/python2.7/site-packages" >> ~/.bash_profile
source ~/.bash_profile

echo "create soft link to librados.."
ls -s ${ceph_root}/ceph-0.94.5/src/.libs/librados.so* /usr/lib
sudo ldconfig

echo "create cluster configure file..."
if [ -d /etc/ceph ]; then
   echo "delete old /etc/ceph...."
   rm -r /etc/ceph
fi
echo "create dir:/etc/ceph..."
mkdir -p /etc/ceph

hostname=`hostname`
echo "generate fsid..."
fsid=`uuidgen`
echo "ceph fsid is ${fsid} "
#apt-get install awk
echo "get ip address(eth0's address)"
ip=`ifconfig eth0 | grep "inet addr" | awk '{ print $2}' | awk -F: '{print $2}'`
net=${ip%.*}.0/24
echo "network is ${net}"

echo "creating ceph.conf..."
touch /etc/ceph/ceph.conf
echo "[global]" >> /etc/ceph/ceph.conf
echo "fsid = ${fsid}" >> /etc/ceph/ceph.conf
echo "mon_initial_members = ${hostname}" >> /etc/ceph/ceph.conf
echo "mon_host = ${ip}" >> /etc/ceph/ceph.conf
echo "public_network =${net}" >> /etc/ceph/ceph.conf
echo "auth_cluster_required = cephx" >> /etc/ceph/ceph.conf
echo "auth_service_required = cephx" >> /etc/ceph/ceph.conf
echo "auth_client_required = cephx" >> /etc/ceph/ceph.conf
echo "osd_journal_size = 1024" >> /etc/ceph/ceph.conf
echo "osd_pool_default_size = 3" >> /etc/ceph/ceph.conf
echo "osd_pool_default_min_size = 1" >> /etc/ceph/ceph.conf
echo "osd_pool_default_pg_num = 64" >> /etc/ceph/ceph.conf
echo "osd_pool_default_pgp_num = 64" >> /etc/ceph/ceph.conf
echo "osd_crush_chooseleaf_type = 0" >> /etc/ceph/ceph.conf

echo "create ceph.conf success..."

echo "*********************************************************************************************"

echo "config a mon node ..."
if [ -d /var/log/ceph/ ];then
    echo "delete the old /etc/ceph..."
    rm -r /var/log/ceph/
  fi
  mkdir -p /var/log/ceph/

  if [ -d /var/lib/ceph/mon/ ];then
    echo "delete the old /var/lib/ceph/mon/..."
    rm -r /var/lib/ceph/mon/
  fi

  if [ -d /var/run/ceph/ ];then
    echo "delete the old /var/run/ceph/..."
    rm -r /var/run/ceph/
  fi

  if [ -f /tmp/ceph.mon.keyring ];then
    rm /tmp/ceph.mon.keyring
  fi

  if [ -f /tmp/monmap ];then
    rm /tmp/monmap
  fi

  echo "create admin keyring and secret..."
  ceph-authtool --create-keyring /tmp/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'
  echo "create client.admin and add it to ceph.client.adminkeyring..."
  ceph-authtool --create-keyring /etc/ceph/ceph.client.admin.keyring --gen-key -n client.admin --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow'
  echo "add client.admin to ceph.mon.keyring..."
  ceph-authtool /tmp/ceph.mon.keyring --import-keyring /etc/ceph/ceph.client.admin.keyring
  echo "create a monitor map..."
  monmaptool --create --add ${hostname} ${ip} --fsid ${fsid} /tmp/monmap
  echo "create mon data directory..."
  mkdir -p /var/lib/ceph/mon/ceph-${hostname}
  echo "create mon deamon..."
  ceph-mon --mkfs -i ${hostname} --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring
  echo "start ceph-mon..."
  ceph-mon -i ${hostname}
  echo "write mon config to ceph.conf..."
  echo "[mon.${hostname}]" >> /etc/ceph/ceph.conf
  echo " host = ${hostname}" >> /etc/ceph/ceph.conf
  echo " mon addr = ${ip}:6789" >> /etc/ceph/ceph.conf
  ceph -s

echo "*********************************************************************************************"


echo "add some OSDs ..."

if [ ! -f "/sbin/mkfs.xfs" ]; then
 apt-get install xfsprogs
fi

while [ -z ${osd_num} ]
do
  read -p "please input osd number(e.g: 3):" osd_num
  if grep '^[[:digit:]]*$' <<< "${osd_num}"; then
    echo "osd number is : ${osd_num}"
  else
    echo "using default osd_num=3"
    osd_num=3
  fi
done

echo "input part disk type:"
echo "1.one disk for ${osd_num} OSDs"
echo "2.one disk for one OSD"
read -p "(default is 1)>" part_type
if [ ${part_type} = 2 ]; then
#*******************one disk for one OSD***********************
for((i=1; i<=${osd_num}; i++)); do
     result="result"
     unset disk
     while [ "${result}" != "${disk}" ]
     do
        echo "warn:do not repeat disk to behind disk!!"
        read -p  "input disk ${i} path(e.g: /dev/vdc):" disk
        if [ -n "${disk}" ];then
          result=`ls ${disk}`
          if [ -n "${result}" ]; then
             echo "exist ${disk}"
             disk_array[${i}]=${disk}
          else
            echo "not exist ${disk},please try again.."
          fi
        fi
     done
done

for ((i=1; i<=${osd_num}; i++)); do

 echo "
n




w
"| fdisk ${disk_array[${i}]} && mkfs.xfs -f ${disk_array[${i}]}
done
#*******************one disk for one OSD***********************
else
     #*******************one disk for ${osd_num} OSDs***********************
     result="result"
     while [ "${result}" != "${disk}" ]
     do
      read -p  "input disk path(e.g: /dev/vdc):" disk
      if [ -n "${disk}" ];then
        result=`ls ${disk}`
        if [ -n "${result}" ]; then
         echo "exist ${disk}"
        else
         echo "not exist ${disk},please try again.."
        fi
      fi
     done

     avail=`fdisk -l ${disk} | head -2 | cut -d: -f2 | cut -d, -f1 | cut -d' ' -f2`
     avail=${avail:1}
     echo "avail space is :${avail} GB"

     space_per=$(echo "${avail}/${osd_num}"|bc)
     echo "space_per is ${space_per}"

     echo "the following operation will erase all the things from ${disk}"
     read -p "input y to continue,else to exit:" input
     if [ ${input} != "y" ]; then
       exit
     fi

mkfs.xfs -f ${disk}

for ((i=1; i<=${osd_num}; i++)); do
 disk_array[${i}]=${disk}${i}
 if [ ${i} != ${osd_num} ];then
 echo "
n



+${space_per}GB
w
"| fdisk ${disk} && mkfs.xfs -f ${disk}${i}
 else
 echo "
n




w
"| fdisk ${disk} && mkfs.xfs -f ${disk}${i}
fi
done
#*******************one disk for ${osd_num} OSDs***********************
fi

sed -i '$d' /etc/rc.local

for ((i=1; i<=${osd_num}; i++)); do
     osd_id=`ceph osd create`
     echo "osd.${osd_id} is creating...."
     echo "create path:/var/lib/ceph/osd/ceph-${osd_id} success!"
     rm -rf /var/lib/ceph/osd/ceph-${osd_id}   
     mkdir -p /var/lib/ceph/osd/ceph-${osd_id}
     mkfs.xfs -f ${disk_array[${i}]}
     echo "mount ${disk_array[${i}]} success!"
     mount ${disk_array[${i}]} /var/lib/ceph/osd/ceph-${osd_id}
     echo "mount ${disk_array[${i}]} /var/lib/ceph/osd/ceph-${osd_id}" >> /etc/rc.local
     cd /var/lib/ceph/osd/ceph-${osd_id}
     ceph-osd -i ${osd_id} --mkfs --mkkey
     ceph osd crush add ${osd_id} 1.0 host=${hostname}
     ceph auth add osd.${osd_id} osd "allow *" mon 'allow rwx' -i keyring
     #serivce ceph start osd.${osd_id}
     ceph-osd -i ${osd_id}
     echo "write config to ceph.conf ..."
     echo "[osd.${osd_id}]" >> /etc/ceph/ceph.conf
     echo " host = ${hostname}" >> /etc/ceph/ceph.conf
     echo " deves = ${disk_array[${i}]}" >> /etc/ceph/ceph.conf
done

echo "exit 0" >> /etc/rc.local

echo "set crush root..."
ceph osd crush move ${hostname} root=default
echo "******************************Done!******************************"
echo "++++++++++++++ceph status:++++++++++++++"
ceph -s
ceph osd tree


#################write service###############
echo "write ceph to service...."
sed  -i 's/\/usr\/local\/etc\/ceph/\/etc\/ceph/g' ${path}/${version}/src/init-ceph
ln -s ${path}/${version}/src/init-ceph /etc/init.d/ceph

################start when host is on###############
sed -i '$d' /etc/rc.local
echo "${path}/${version}/src/ceph-mon -i ${hostname}" >> /etc/rc.local
for ((i=0; i<${osd_num}; i++ )); do
  echo "${path}/${version}/src/ceph-osd -i ${i}" >> /etc/rc.local
done

echo "exit 0" >> /etc/rc.local