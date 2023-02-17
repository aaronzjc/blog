---
layout: post
title: "配置HTTPS自签名证书"
date:   2020-09-23 22:00:00 +0800
categories: web
---
## 介绍

在web开发中，经常需要与https打交道。通常开发环境，都会忽略https，使用http进行开发。等到测试通过后，线上再切换到https就可以了。这种方式对于一般的开发而言，没什么问题。但是对于一些特殊场景，就有限制了。

例如，在sso登录授权中，为了安全，会对cookie做一个安全设置。如下是微博m站的cookie信息

![img](/static/assert/imgs/https_local_1.png)

注意后面的`HttpOnly`和`Secure`两个属性。`HttpOnly`是为了限制js脚本获取本地cookie。这个作用是为了防止xss攻击。`secure`属性表明只有在https请求时才会传输。所以这种情况，只有配置https访问，才能够正常的传递cookie信息。实际经测试，在错误的https配置下，这两个属性的cookie还是会传过去。但是，配置自签名https证书用于开发测试还是有必要的。

## 配置自签名HTTPS证书

根据https的证书认证流程，可以直接生成一对证书，然后，添加证书到系统信任即可。但是这样不太方便，因为后面如果还有其他的域名，那么我们每次都要生成一对证书，然后添加到信任里面。更好的方式是，本地作为一个CA证书机构，然后给想要的域名颁发证书。本地只需要信任CA的证书即可。

上面的过程需要如下几个步骤

+ 本地创建一个CA证书颁发机构
+ 给想要的域名生成一个https证书
+ 信任CA机构的根证书

按照流程，首先创建CA机构证书

```shell
$ export CA_NAME=myca
$ openssl genrsa -des3 -out $CA_NAME.key 2048
$ openssl req -x509 -new -nodes -key $CA_NAME.key -sha256 -days 825 -out $CA_NAME.pem
```

接着，利用CA机构的证书和私钥，来颁发域名证书

```shell
$ export DOMAIN_NAME=test.memosa.local
$ openssl genrsa -out $DOMAIN_NAME.key 2048
$ openssl req -new -key $DOMAIN_NAME.key -out $DOMAIN_NAME.csr
# Chrome需要证书中必须包含一些扩展字段
$ >$DOMAIN_NAME.ext cat <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = $DOMAIN_NAME
EOF
$ openssl x509 -req -in $DOMAIN_NAME.csr -CA $CA_NAME.pem -CAkey $CA_NAME.key -CAcreateserial -out $DOMAIN_NAME.crt -days 825 -sha256 -extfile $DOMAIN_NAME.ext
```

最后，添加`$CA_NAME.pem`到系统的信任。服务器配置`$DOMAIN_NAME.key`和`$DOMAIN_NAME.crt`即可。

值得注意的是，在`osx`系统中，`Chrome`只需要在钥匙链中信任CA证书即可。`Firefox`需要手动导入到它的证书配置中。

我根据上面的流程，写了个证书生成的[小工具](https://tools.memosa.cn/#/cert)。有需要的话，可以参考使用。