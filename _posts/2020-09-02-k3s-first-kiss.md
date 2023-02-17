---
layout: post
title: "k8s小试牛刀"
date:   2020-09-01 22:00:00 +0800
categories: linux
---

终于能够写一篇`k8s`相关的文章了。在2018年的时候，一个很佩服的同事说过，以后肯定是`k8s`的未来。彼时，我才刚知道Docker，处于刚开始上手的阶段。他的这句话，就让我对这个东西产生了很大的兴趣。后来有时间就了解这方面的知识。因为它安装麻烦，配置要求高，就不是很用力的去实践。于是，从`swarm`入手，开始实践，折腾。

随着发展，`k8s`也确实越来越火了。相关的技术也层出不穷，终于迎来了`k3s`这个项目。`k3s`是一个非常轻量级的`k8s`发行版，阉割了很多不必要的特性，能够运行在低配置的环境。正好，`Mu`项目也在swarm上跑了一年，经过不断的迭代，已经做好了迁移的准备。

最近，经过调研，终于决定动手了。没想到，迁移比我想象的顺利多了，晚上在家熬了两个小时就搞定了。

这篇文章主要是介绍下自己对`k8s`的理解，以及自己实践相关的内容。

### k3s

关于`k3s`的介绍，官方的[文档](https://rancher.com/docs/k3s/latest/en/)介绍的非常详细。包括如何安装，阉割了那些东西，包含哪些组件。

和本次实践相关的`k8s`概念有：`Pod`，`Deployment`，`Service`，`Ingress`，`Namespace`，`ConfigMap`。

`Pod`是一组容器的集合，就像豆荚。它是`k8s`中调度的最小单位，在`swarm`中，最小单位是容器。例如，一个FPM进程不能直接对外提供服务，一般需要一个Nginx作为代理，两者结合才能实现一个完整的服务。容器也往往不是孤立的。所以，就有了`Pod`的概念。

`Deployment`是一种`k8s`资源对象。它主要是描述一个应用的状态，例如，用的哪些个镜像，包含几个`Pod`副本。只要提供了应用的状态描述文件，就可以很方便的部署一个应用。这也是容器技术火热的原因之一。

`Service`即是服务。在`k8s`中，如果只是部署了`Pod`，它只能在集群内访问。并且，访问单个`Pod`也没有意义。通常这几个`Pod`合并在一起才算一个完整的服务。`Service`提供了一种方式，可以让外界可以轻松访问这些`Pod`。它有`ClusterIp`，`NodePort`，`LoadBalancer`这几种方式。第一种是只在集群内部可访问；第二种则是在每个`k8s`节点都暴露一个端口，然后访问任何一个节点的这个端口，都能路由到`Pod`。和之前介绍过的swarm中的overlay一样；第三种，则是需要云厂商支持的负载均衡模式。想想，我们部署多个Nginx服务，往往会在前面架一个负载均衡器。就是如此。

`Ingress`也是比较重要的一个概念。什么是`Ingress`？它是`k8s`中的一个资源对象，用于管理`Service`的。为什么需要`Ingress`呢？我们来看传统的服务是怎么管理的。假设有5个Go服务跑在一个服务器上，它们每个都占用一个端口。怎么方便访问呢？通常会在前面加一个Nginx作为反向代理，用于域名解析和SSL等。同样的，`Service`固然能够暴露服务给外界。但是，每个`Service`占用一个端口，且不能通过域名和路径等来区分服务，只能通过端口。这就不方便了，于是就有了`Ingress`。`Ingress`很好用，但是我在部署的时候，并没有用上，甚至还卸载了自带的`traefik`。后面会介绍为什么。

`Namespace`，命名空间。一想就知道用于资源隔离，权限控制等。

`ConfigMap`即是配置。既然是服务，服务就少不了配置，所以`k8s`提供了`ConfigMap`对象来方便管理配置等。

`k8s`中还有很多其他的资源对象，每一个都有其对应的应用场景。这也是`k8s`越来越火的原因，它提供了一整套架构方案来支持应用容器化。

最后，看一下，在`k8s`中，请求是如何到达应用的

![img](/static/assert/imgs/k3s_1.png)

### 我的部署实践

首先，`Mu`有3个组件，接口`api`组件，调度器`commander`组件，执行器`agent`组件。需要3个部署文件。

1、首先，创建一个命名空间

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: k3s-apps
```

2、其次，创建一个配置文件

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mu-config
  namespace: k3s-apps
data:
  app.json: |
    12345
```

3、部署各个组件

```yaml
# mu-api.yml
apiVersion: v1
kind: Service
metadata:
  name: mu-api-svc
  namespace: k3s-apps
spec:
  selector:
    app: mu-api
  type: NodePort
  ports:
  - port: 80
    nodePort: 30080
    targetPort: 7980
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mu-api
  namespace: k3s-apps
spec:
  selector:
    matchLabels:
      app: mu-api
  replicas: 2
  revisionHistoryLimit: 1
  template:
    metadata:
      labels:
        app: mu-api
    spec:
      volumes:
      - name: mu-conf
        configMap:
          name: mu-config
      containers:
      - name: mu-api
        image: aaronzjc/mu-api:latest
        volumeMounts:
        - name: mu-conf
          mountPath: /app/conf
        ports:
        - containerPort: 7980
        resources:
          limits:
            cpu: 100m
            memory: 50Mi
```

```yaml
# mu-commander.yml
apiVersion: v1
kind: Service
metadata:
  name: mu-commander-svc
  namespace: k3s-apps
spec:
  selector:
    app: mu-commander
  type: NodePort
  ports:
  - port: 80
    nodePort: 30070
    targetPort: 7970
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mu-commander
  namespace: k3s-apps
spec:
  selector:
    matchLabels:
      app: mu-commander
  replicas: 2
  revisionHistoryLimit: 1
  template:
    metadata:
      labels:
        app: mu-commander
    spec:
      volumes:
      - name: mu-conf
        configMap:
          name: mu-config
      containers:
      - name: mu-commander
        image: aaronzjc/mu-commander:latest
        volumeMounts:
        - name: mu-conf
          mountPath: /app/conf
        ports:
        - containerPort: 7970
        resources:
          limits:
            cpu: 100m
            memory: 50Mi
```

```yaml
# mu-agent.yml
apiVersion: v1
kind: Service
metadata:
  name: mu-agent-zyra-svc 
  namespace: k3s-apps
spec:
  selector:
    app: mu-agent-zyra
  type: NodePort
  ports:
  - port: 80
    nodePort: 30091
    targetPort: 7990
---
apiVersion: v1
kind: Pod
metadata:
  name: mu-agent-zyra
  namespace: k3s-apps
  labels:
    app: mu-agent-zyra
spec:
  containers:
  - name: mu-agent-zyra
    image: aaronzjc/mu-agent:latest
    ports:
      - containerPort: 7990
    resources:
      limits:
        cpu: 100m
        memory: 50Mi

---
apiVersion: v1
kind: Service
metadata:
  name: mu-agent-nami-svc 
  namespace: k3s-apps
spec:
  selector:
    app: mu-agent-nami
  type: NodePort
  ports:
  - port: 80
    nodePort: 30092
    targetPort: 7990
---
apiVersion: v1
kind: Pod
metadata:
  name: mu-agent-nami
  namespace: k3s-apps
  labels:
    app: mu-agent-nami
spec:
  containers:
  - name: mu-agent-nami
    image: aaronzjc/mu-agent:latest
    ports:
      - containerPort: 7990
    resources:
      limits:
        cpu: 100m
        memory: 50Mi
```

然后就没了。搭好环境，几个配置文件，就是这么简单。

前面提到为什么没有用到`Ingress`。因为我只有一台1C2G的小主机，没有分布式的环境，`Pod`不会调度到其他的机器。所以，对我而言，`Service`用`ClusterIp`和`NodePort`方式都是可行的。因为当服务重启或者重新部署时，`ClusterIp`可能会变，但是`NodePort`定义的端口不会变，所以`Service`选择了`NodePort`。

因为我通过服务器IP+端口方式可以访问到`Service`了，在这个场景，`Ingress`和传统的Nginx反向代理的方式，区别并不大。都是做域名解析和SSL等。考虑到我的服务器安装了一些其他非容器应用，例如，`MySQL`，`Redis`，`*ray`等。如果通过`Service`将它们映射到`k8s`，再通过`Ingress`代理，这样显得有点多此一举。没有Nginx反代这种传统方式来的方便。所以最终我的服务器部署如下

![img](/static/assert/imgs/k3s_2.png)

## 最后

这只是一个非常好的开端。现在只是进行了简单的部署，还有很多内容值得学习折腾。例如，将`k8s`部署和`Github Action`结合，实现自动化部署。再就是使用`sidecar`模式采集日志。还有`helm`。等等。