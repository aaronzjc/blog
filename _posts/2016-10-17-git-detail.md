---
layout: post
title: "《Pro Git》笔记-Git原理简单介绍"
date:   2016-10-16 10:00:00 +0800
categories: linux
---
# Git对象

Git有四种对象，数据对象(blob)，树对象(tree)，提交对象(commit),标签对象(tag)。

## blob

数据对象是二进制组成的数据文件。用来存储，Git仓库中的各种文件，代码，等。

首先初始化一个Git目录

```shell
>git init test
>cd test/.git/objects
```

可以看到objects目录下只有两个空的目录，info和pack。现在，按照一般的操作，向Git暂存区添加一个文件README。

```shell
>echo 'hello world' > one.txt
>git add .
```

现在，objects目录中，多了一个目录和文件。
```shell
3b/
3b/18e512dba79e4c8300dd08aeb37f8e728b8dad
```

该文件就是一个数据对象。有意思的是，这里的文件命名很特别。
这儿，就涉及到Git存储文件的方式了。当添加文件时，Git根据文件的内容，加上特定的头信息，进行SHA-1校验和，然后取校验和的前两位作为目录，其他位作为文件名存储为一个数据文件。可以利用Git提供的工具来验证一下。

```shell
>git hash-object one.txt
3b18e512dba79e4c8300dd08aeb37f8e728b8dad
```

因为，Git是根据内容来生成的这么一个文件名。所以，当两个文件一样时，生成的字符串也一定一样，因此，可以通过对比来判断文件是否修改。

用普通的编辑器打开这个文件，发现文件内容是乱码。因为这里，Git并不是直接存储的。而是，进行了压缩处理。可以，通过Python交互命令行，来查看这个文件。

```shell
>python3
>>>lines = open("18e512dba79e4c8300dd08aeb37f8e728b8dad","rb").read()
>>>import zlib
>>>zlib.decompress(lines)
b'blob 12\x00hello world\n'
```

12是内容长度

也可以通过Git提供的工具，来查看文件内容。
```shell
>git cat-file -t 3b18e512dba79e4c8300dd08aeb37f8e728b8dad
blob
>git cat-file -p 3b18e512dba79e4c8300dd08aeb37f8e728b8dad
hello world
```

## tree

树对象类似于文件系统中的目录。一个树对象包含，一个或多个树对象的记录，然后每个记录指向数据对象或者子树对象。这里，我们提交一个文件，然后，执行如下命令

```shell
>git cat-file -p HEAD
tree 1bbb4a9fcf999913a2213ac82b1cbfaf090706b5
author ...
committer ...
...
>git cat-file -p 1bbb4
100644 blob 3b18e512dba79e4c8300dd08aeb37f8e728b8dad    one.txt
```

可以看到，1bbb4是一个tree对象，其内容为指向one.txt的值。

## commit

当每次执行提交操作时，Git创建提交对象。这也是Git和其他版本系统不同的地方，Git每次提交时都保存文件系统的快照。介绍树对象时，有这么一个命令

```shell
git cat-file -p HEAD
```

他的意思就是查看最后一次提交对象的内容。可以看到提交对象的内容也比较简单，根据暂存区内容创建的顶层树对象，提交用户信息，和提交信息，以及一个指向父提交对象字符串(第一次提交的提交对象没有父提交对象)。

同样的也可以使用工具来查看提交对象

```shell
>git log
commit 6af19b98492a11ad962a2cc1d06ee94f2400d2cc
...
> git cat-file -t 6af19
commit
```

经过一系列的提交之后，我们看到的提交结构就是如下的样子

![commit]({{ site.url }}/assert/imgs/git_1.png)

## tag

tag对象就是指向特定的一次提交对象。我们可以创建一个tag，查看来验证

```shell
>git tag v1.0
>git tag -l
v1.0
>git cat-file v1.0
tree d4e5bc1c2220cd66199d8fb1c048f60df63b7181
parent 2920d926279b36c3eeb04dcf1f3f170479fe55fe
author ...
committer ...

rebase init
>git cat-file -p HEAD
# 内容同上
```

和commit的内容一致。

## Git提交时在做什么

上面简单介绍了Git的几个基础对象。接下来，结合Git实际的应用来说明，对象是如何作用的。

Git将整个项目分为三个部分，工作区，暂存区，和本地数据库。

### 本地编辑文件

这里创建一个普通的文件。此时，文件创建之后，仅存在于本地工作区中，还没有被Git追踪。

```shell
>echo "hello world" > one.txt
```

### 添加至暂存区

将文件添加至暂存区。这个时候，Git根据添加的文件，创建数据对象，保存至.git/objects目录下。文件是，数据类型和内容，进行校验和算法生成的字符串。前两位是文件目录，后面的是文件名。

```shell
>git add .
```

### 提交文件

提交时，Git创建一个提交对象，指向上一步创建的树对象。将文件记录至本地数据库。

```shell
>git commit -m 'init'
```

# Git分支

版本系统中，分支是一项十分重要的特性。我们可以根据项目情况切换到不同的分支，迭代开发，而不影响其他主体代码的功能。

Git分支本质是指向提交对象的指针。上面介绍过，每次提交时，Git都会创建一个提交对象。然后，Git分支就是指向最新的这次提交。

![branch]({{ site.url }}/assert/imgs/git_2.png)

Git创建分支也十分简单

```shell
>git branch issue11 # 创建分支
>git checkout issue11 # 切换分支
```

切换分支是，Git通过一个HEAD文件来记录当前分支

```shell
>cat .git/HEAD
ref: refs/heads/master
```

分支在Git中的储存，可通过如下方式来查看，可以看到，分支的内容即是指向最后一次提交对象的指针。

```shell
>ls .git/refs/heads
issue11 master
>cat .git/refs/heads/master
6af19b98492a11ad962a2cc1d06ee94f2400d2cc
>git cat-file -p 6af19
tree 1bbb4a9fcf999913a2213ac82b1cbfaf090706b5
author ...
committer ...
...
```


## 合并和变基

当我们在进行项目迭代时，往往会涉及到分支合并操作。例如，我们在开发中，Z同学遇到一个紧急的Bug需要修复，这时候，他新建一个分支bug11，然后，进行修改。此时，master主分支上，其他人可能刚好提交了另一个需求，这样，整个提交历史就是如下了

![branch]({{ site.url }}/assert/imgs/git_3.png)

这时候，如果Z同学自己测试没问题了。想合并至主分支，首先，切换回master分支，然后执行git merge操作

如果，两个分支修改的是同一个地方，那不出意外的是，会出现冲突了。Git不知道这两个修改以哪个为主。
冲突之后，文件冲突的地方会标示出来，修改了冲突地方，重新添加提交就好了。

```shell
>git checkout master
>git merge
...
fix conflicts
...
>git add .
>git commit -m 'fix' # 提交完成

>git log --graph --all --abbrev-commit --decorate --oneline # 查看提交记录
```

![rebase]({{ site.url }}/assert/imgs/git_4.png)

可以看到上面的分支图。上面的操作就是合并。

同样的情况，还可以用变基解决。变基就是，将分支的修改，打到master上，最后成功后，提交历史看上去就是线性的。

如下，是分支的简图

![conflicts]({{ site.url }}/assert/imgs/git_5.png)

我们将bug1的修改变基到master

```shell
(bug1)>git rebase master
(master)>git merge #解决冲突后，合并
```

解决冲突，变基成功后的流程如下，之后再进行快进merge即可完成合并

![rebase]({{ site.url }}/assert/imgs/git_6.png)

# .git目录

最后大致介绍一个.git目录下的内容

```shell
>find .git
.git
.git/COMMIT_EDITMSG
.git/config # git config的配置信息
.git/description # 分支描述
.git/HEAD # 指向当前分支的指针

.git/hooks # 钩子，用来触发Git提交等事件的处理
.git/hooks/applypatch-msg.sample
.git/hooks/commit-msg.sample
.git/hooks/post-update.sample
.git/hooks/pre-applypatch.sample
.git/hooks/pre-commit.sample
.git/hooks/pre-push.sample
.git/hooks/pre-rebase.sample
.git/hooks/prepare-commit-msg.sample
.git/hooks/update.sample

.git/index # 暂存区

.git/info
.git/info/exclude # 用来忽略文件

.git/logs # 提交日志
.git/logs/HEAD
.git/logs/refs
.git/logs/refs/heads
.git/logs/refs/heads/bug1
.git/logs/refs/heads/master

.git/objects # Git本地对象
.git/objects/10
.git/objects/10/c769ecce6c6686454c25f66ca95068b49d1b49
.git/objects/info
.git/objects/pack

.git/ORIG_HEAD # HEAD的之前状态

.git/refs # Git分支
.git/refs/heads
.git/refs/heads/bug1
.git/refs/heads/master
.git/refs/tags # Git Tag对象

.git/objects/pack
```

这里解释下这个目录。试想一下，Git每次都是存储提交的暂存快照。如果，有一个文件特别大。如果每次，都暂存这个文件的快照的话，无疑持续下去，会导致Git本地库越来越大。Git的处理，就是，查找相似的文件，然后只保存文件之间差异的部分。这样，就可以使得文件比较小。pack目录就是存储包文件的。

参考内容

* [《Pro Git第二版》](https://www.gitbook.com/book/bingohuang/progit2/details)
* [Git 原理](https://chenyiqiao.gitbooks.io/git/content/)
* [Git 包文件](https://git-scm.com/book/zh/v2/Git-%E5%86%85%E9%83%A8%E5%8E%9F%E7%90%86-%E5%8C%85%E6%96%87%E4%BB%B6)
