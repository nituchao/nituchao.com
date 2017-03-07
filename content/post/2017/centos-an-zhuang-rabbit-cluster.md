---
title: "在CentOS上安装Rabbitmq集群"
date: "2017-03-02T17:35:54+08:00"
categories: ["Amqp"]
tags: ["Rabbitmq"]
draft: false
---

## 系统环境

* CentOS 7 四台



## 安装包准备

* wxBase-2.8.12-1.el6.centos.x86_64.rpm
* wxGTK-2.8.12-1.el6.centos.x86_64.rpm
* wxGTK-gl-2.8.12-1.el6.centos.x86_64.rpm
* esl-erlang_19.2.3~centos~6_amd64.rpm
* otp_src_19.1.tar.gz
* rabbitmq-server-3.6.6-1.el6.noarch.rpm



## 安装Erlang环境

```shell
# yum localinstall wxBase-2.8.12-1.el6.centos.x86_64.rpm
# yum localinstall wxGTK-2.8.12-1.el6.centos.x86_64.rpm
# yum localinstall wxGTK-gl-2.8.12-1.el6.centos.x86_64.rpm
# yum localinstall esl-erlang_19.2.3~centos~6_amd64.rpm
# yum install build-essential openssl openssl-devel unixODBC unixODBC-devel make gcc gcc-c++ kernel-devel m4 ncurses-devel tk tc
# tar -zxvf otp_src_19.1.tar.gz
# cd otp_src_19.1
# ./configure --prefix=/home/erlang --without-javac
# make && make install
```

安装完Erlang之后，修改/etc/profile增加

export PATH=$PATH:/home/erlang/bin

执行source /etc/profile使得环境变量生效



## 安装Rabbitmq

### 安装rabbitmq

```shell
# rpm --import https://www.rabbitmq.com/rabbitmq-release-signing-key.asc
# rpm --nodeps -Uvh rabbitmq-server-3.6.6-1.noarch.rpm
```



### 添加开机启动

```shell
# chkconfig rabbitmq-server on
# service rabbitmq-server start
```



### 开启web管理界面

```shell
# rabbitmq-plugins enable rabbitmq_management
```



### 添加用户

```shell
# rabbitmqctl add_user work workO^m15213
# rabbitmqctl set_user_tags work administrator
# rabbitmqctl set_permissions -p / work ".*"".*"".*"
```

