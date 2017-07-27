---
"categories": ["Zookeeper"],
"tags": ["Zookeeper"],
"date": "2017-07-25T13:32:00+08:00",
"title": "Zookeeper源码阅读环境搭建"

---

### 1，从Github上检出Zookeeper项目代码

在Github上搜索zookeeper，找到Apache下的Zookeeper项目，然后下载zip包，也可以使用下面的命令检出源代码，然后切换到zookeeper-3.5分支上。

```shell
$ git clone https://github.com/nituchao/zookeeper.git
$ git checkout -b zookeeper-3.5 remotes/origin/branch-3.5
```

检出源代码后，使用`ll -a`命令，可以看到源码结构如下：

```shell
$ ll -a
total 304
drwxr-xr-x  17 liang  staff   578B Jul 25 10:37 .
drwxr-xr-x   4 liang  staff   136B Jul 25 10:24 ..
drwxr-xr-x  13 liang  staff   442B Jul 25 10:48 .git
-rw-r--r--   1 liang  staff   483B Jul 25 10:37 .gitattributes
-rw-r--r--   1 liang  staff   810B Jul 25 10:37 .gitignore
-rw-r--r--   1 liang  staff    11K Jul 25 10:37 LICENSE.txt
-rw-r--r--   1 liang  staff   170B Jul 25 10:37 NOTICE.txt
-rw-r--r--   1 liang  staff   1.6K Jul 25 10:37 README.txt
-rw-r--r--   1 liang  staff   1.3K Jul 25 10:37 README_packaging.txt
drwxr-xr-x  11 liang  staff   374B Jul 25 10:37 bin
-rw-r--r--   1 liang  staff    80K Jul 25 10:37 build.xml
drwxr-xr-x   5 liang  staff   170B Jul 25 10:37 conf
drwxr-xr-x  49 liang  staff   1.6K Jul 25 10:37 docs
-rw-r--r--   1 liang  staff   4.0K Jul 25 10:37 ivy.xml
-rw-r--r--   1 liang  staff   1.7K Jul 25 10:37 ivysettings.xml
drwxr-xr-x  13 liang  staff   442B Jul 25 10:37 src
-rw-r--r--   1 liang  staff    21K Jul 25 10:37 zk-merge-pr.py
```



### 2，使用ant将源码编译为eclipse工程

上一步检出来的源码并不是maven工程或者eclipse工程，需要使用`ant eclipse`命令来转换成eclipse工程。在执行ant命令前，请编辑`build.xml`文件，搜索`ant-eclipse-1.0.bin.tar.bz2`，然后将该文件的下载地址更新成新地址，防止在ant的过程中发生错误。

```shell
# 更换前
get src="http://downloads.sourceforge.net/project/ant-eclipse/ant-eclipse/1.0/ant-eclipse-1.0.bin.tar.bz2"

# 更换后
get src="http://ufpr.dl.sourceforge.net/project/ant-eclipse/ant-eclipse/1.0/ant-eclipse-1.0.bin.tar.bz2"
```

修改好`build.xml`之后，使用下面的命令生成eclipse项目：

```shell
$ cd zookeeper
$ ant eclipse
```

3，通过Idea导入eclipse工程

打开IntelliJ IDEA，依次选择`File` -> `New` -> `Project From Existing Sources`，打开导入对话框，按照下面的顺序导入Zookeeper项目源代码。

a) 选择导入Eclipse项目

![IDEA Import Eclipse Project](http://olno3yiqc.bkt.clouddn.com/idea_eclipse_import.png)



b) 选择项目目录 

![选择项目目录](http://olno3yiqc.bkt.clouddn.com/idea_directory.png)



c) 选择导入的项目

![选择导入的项目](http://olno3yiqc.bkt.clouddn.com/idea_zookeeper_project_select.png)

### 设置运行环境

Zookeeper的运行环境要求JDK 1.7+，因此要在项目设置里指定JDK版本。另外，将语言等级提示设置为7，这样可以避免IDEA对很多JDK 1.7以上的新语法的错误提示。

![设置JDK](http://olno3yiqc.bkt.clouddn.com/jdk-setting.png)



### 运行Zookeeper

单机版Zookeeper的启动类是`org.apache.zookeeper.server.ZooKeeperServerMain`，找打它的`main`函数，然后右键"Debug"就可以启动Zookeeper的服务器端程序，由于没有使用任何参数，Zookeeper使用默认配置参数。启动后，在控制台会有如下输出，这实际是Zookeeper启动的一个命令行控制台，可以接受输入命令。

```shell
Welcome to ZooKeeper!
JLine support is enabled
[zk: localhost:2181(CONNECTING) 0]
```



### 结束语

最近为了研究Zookeeper的源代码花了不少精力。Zookeeper源码使用Ant + Ivy来管理，而没有使用Maven来管理。另外，Zookeeper默认的是Eclipse开发环境，要导入到IDEA中需要转换和配置，最后经过几番尝试，终于配置成功，项目不会报错，可以直接Debug，也算是完美。