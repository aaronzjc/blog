---
layout: post
title: "Docker Swarm网络相关"
date:   2020-06-07 22:00:00 +0800
categories: linux
---

## 简介

最近在折腾Docker Swarm相关的服务部署。我有两台垃圾vps机器，一台1C2G，另一台1C1G。勉强组一个Swarm集群没有问题。虽然在容器编排领域，Swarm是败给了K8s。但是，对于一些小型项目而言，Swarm的一些特性还是挺好用的。例如，Docker内置，操作简单，会使用Docker Compose，就可以立马上手Swarm。

在Swarm中部署一个`service`时，Swarm可以根据情况将容器部署在集群中的不同节点。访问`service`提供的vip，可以根据自带的负载均衡路由到容器，哪怕不在同一个物理节点。后续的扩容，缩容等操作，也不会影响到服务访问。所以，`service`网络功能是怎么做到的呢？于是，进行了一番学习。

## Swarm用到的网络技术



### iptables

#### 介绍

#### 实践

### overlay network

### vxlan

## 总结