---
layout: post
title: "k8s业务日志收集"
date:   2020-10-27 22:00:00 +0800
categories: linux
---

费了一些功夫将`Mu`切换到了k8s环境了，运行比较稳定。接着立马实践的一个问题就是日志收集了。

应用在运行中会产生各种各样的日志，有业务日志，有接口请求日志等。通过将应用产生的日志收集到一起，集中展示，可以方便开发人员了解业务当前的状态。应用有没有异常，访问量多少等。所以，日志系统是IT基础设施中不可或缺的一环。

在没有k8s时，公司通常采用EFK或者ELK套件进行日志收集。大致架构如图

![img](/assert/imgs/logstack_1.png)

首先，将业务日志写到服务器指定的目录，然后，配置一个日志收集程序，将文件发到队列。也有直接代码里发送到队列的。然后，有一个格式化或者过滤器读取队列的日志，经过预处理后，存入到ES集群。基本的日志架构都是如此。

k8s中，收集应用日志的方式也大体如此。有两种方案，一种是将Pod里面的日志统一写入到服务器指定目录，然后部署一个DaemonSet采集器，这样的话，和前面介绍的方式没区别。另一种方式是，每个Pod里面部署一个超轻量级的采集器，收集当前Pod的日志，发到指定的地方。这种也叫sidecar模式，更加符合k8s的逻辑，但是成本更高一些。

我采用的是sidecar模式来收集应用日志。日志技术栈采用`Fluent-bit`+`Loki`+`Grafana`套件。毕竟，要玩就玩新的嘛。整体架构如图

![img](/assert/imgs/logstack_2.png)

为什么采用这套架构呢？因为我的服务器配置很垃圾，应用也很简单，所以按照自己的喜好，肯定是选择最轻量级的方案了。`Fluent-bit`是轻量级的`Fluentd`采集器，`Loki`作为日志存储和索引，`Grafana`用于检索日志。

### 部署

1、部署Pod示例

```yaml
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
      - name: tz-config
        hostPath:
          path: /usr/share/zoneinfo/Asia/Shanghai
      - name: mu-conf
        configMap:
          name: mu-config
      # fluent-bit的配置文件
      - name: fluent-bit-conf
        configMap:
          name: fluent-bit-config
          items:
          - key: parser
            path: parser.conf
          - key: labelMap
            path: labelMap.json
          - key: fluent-bit-api
            path: fluent-bit.conf
      - name: mu-log-dir
        emptyDir: {}
      containers:
      - name: mu-api
        image: aaronzjc/mu-api:latest
        imagePullPolicy: Always
        volumeMounts:
        - name: mu-conf
          mountPath: /app/conf
        - name: mu-log-dir
          mountPath: /var/log
        ports:
        - containerPort: 7980
        resources:
          limits:
            cpu: 100m
            memory: 50Mi
      - name: fluent-bit
        image: grafana/fluent-bit-plugin-loki:latest
        volumeMounts:
        - name: tz-config
          mountPath: /etc/localtime
        - name: mu-log-dir
          mountPath: /var/log
        - name: fluent-bit-conf
          mountPath: /fluent-bit/etc

```

2、部署Loki

可采用原生方式，也可以采用k8s方式。我这采用的是k8s方式

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: loki
  namespace: log-stack
spec:
  selector:
    matchLabels:
      app: loki
  replicas: 1
  revisionHistoryLimit: 1
  template:
    metadata:
      labels:
        app: loki
    spec:
      volumes:
      - name: loki-config
        configMap:
          name: loki-config
      - name: loki-data
        persistentVolumeClaim:
          claimName: loki-pvc
      - name: tz-config
        hostPath:
          path: /usr/share/zoneinfo/Asia/Shanghai
      containers:
      - name: loki
        image: grafana/loki:latest
        imagePullPolicy: Always
        volumeMounts:
        - name: loki-config
          mountPath: /etc/loki
        - name: loki-data
          mountPath: "/loki"
        - name: tz-config
          mountPath: /etc/localtime
        ports:
        - containerPort: 3100
```

3、部署Grafana

我采用的是原生方式部署，因为原生方式就挺简单的。

如上。

### 检索和监控

按照如上的方式，部署成功后，我们就可以查看我们的日志了。首先配置好`grafana`的数据源，然后，在检索中按照`LokiQL`语法进行检索，结果如下

![img](/assert/imgs/logstack_3.png)

和`kibana`一样，`grafaba`不仅仅支持日志检索，还支持日志的聚合图表展示。我们添加一个面板，配置好图表后，就可以得到一个漂亮的监控了

![img](/assert/imgs/logstack_4.png)

如上。我们就在k8s中，实践了日志的收集，展示，监控这些基本操作。

文章中的所有部署文件(除了敏感的配置)，都可以在[这个仓库](https://github.com/aaronzjc/k3s)找到~