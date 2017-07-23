---
"title": "YourKit远程连接线上服务器",
"date": "2017-03-06T09:34:07+08:00",
"categories": ["Daily"],
"tags": ["JVM", "Yourkit"]

---

YourKit是一款业内领先的性能分析工具，目前支持Java和.NET两个平台。该工具功能全面强悍，能通过本地连接或者远程连接的方式，对各种服务器，框架，平台的性能进行分析，并提供了多种由浅入深，针对开发环境或者生产环境的分析模式。该工具提供了高效的图形化显示方式，动动鼠标就可以对系统进行显微镜式的观察分析。



通过YourKit可以对以下内容进行分析：

* CPU profiling - investigate performace issues
* Memory profiling - memory leaks, usage, GC
* Threads and synchronization
* Exception profiling
* Web, Database, I/O



本文想总结一下，YourKit提供的两种连接到Java进程的方式，一种是attach方式，另一种是integrate方式。



## 通过attach方式连接到远程服务器

在控制台，attach方式可以通过进程号，连接到运行中的任何Java进程中，这种方式并不保证总能连接成功，而且会禁用某些分析功能。



#### 线上环境

* CentOS release 6.3 64-Bit
* Java 1.7.0_79 HotSpot(TM) 64-Bit Server VM



#### 下载安装包

```shell
# wget https://www.yourkit.com/download/yjp-2017.02-b53.zip
# unzip yjp-2017.02-b53.zip
# cd yjp-2017.02
```



#### 确定服务进程号

```shell
# jps
2230 Resin
3959 Jps
```



#### Console连接进程

通过下面的命令来连接到Java进程。

```shell
# bin/yjp.sh -attach
[YourKit Java Profiler 2017.02-b53] Log file: /root/.yjp/log/yjp-4473.log
Running JVMs:

Name                             |   PID| Status
-------------------------------- |------|--------------------------------
Resin                            | 11760| Ready for attach
ThriftMain                       |  2934| Ready for attach
Resin                            |  2230| Agent already loaded, agent port is 10001
Resin                            | 14232| Ready for attach
Resin                            |  3657| Ready for attach
WatchdogManager                  | 16411| Ready for attach

Enter PID of the application you want to attach (0 to exit) and press Enter:
>2230
Please specify comma-separated list of startup options, or press Enter for default options (recommended):
>
```

上面的操作执行完成后，会出现如下提示，表示YourKit Console服务已经成功运行，并在10001开始工作。

```shell
Attaching to process 2230 using default options
[YourKit Java Profiler 2017.02-b53] Log file: /root/.yjp/log/yjp-30209.log
The profiler agent has attached. Waiting while it initializes...
The agent is loaded and is listening on port 10001.
You can connect to it from the profiler UI.
# lsof -i:10001
COMMAND  PID USER   FD   TYPE    DEVICE SIZE/OFF NODE NAME
java    2230 root   72u  IPv4 199000044      0t0  TCP *:scp-config (LISTEN)
```

在浏览器，通过ip:port的方式，可以看到YourKit的运行概况。

![YourKit Attach](http://olno3yiqc.bkt.clouddn.com/blog/img/your-kit-attach.png)

#### YourKit UI连接远程服务

打开YourKit UI，点击Connect to remote application，输入IP:PORT进行连接。

![YourKit Connect](http://olno3yiqc.bkt.clouddn.com/blog/img/yourkit-connect-attach.png)

连接成功后，进行性能分析界面，大功告成。

![YourKit性能分析界面](http://olno3yiqc.bkt.clouddn.com/blog/img/yourkit-home-attach.png)



#### 疑难问题

通过attach方式并不总能连接到Java进程，常常会出现JVM无响应的问题，控制台报错如下：

```shell
Attaching to process 31833 using options
com.yourkit.util.bf: com.sun.tools.attach.AttachNotSupportedException: Unable to open socket file: target process not responding or HotSpot VM not loaded
	at com.yourkit.b.f.a(a:128)
	at com.yourkit.b.c.attach(a:1)
	at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	at sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	at java.lang.reflect.Method.invoke(Method.java:498)
	at com.yourkit.h.run(a:17)

Attach to a running JVM failed.

Solution: start JVM with the profiler agent instead of attaching it to a running JVM:
https://www.yourkit.com/docs/java/help/running_with_profiler.jsp
```

因此，分析本地Java进程时可以选择attach方式，对于远程服务，还是推荐integrate方式。



## 通过integrate方式连接到远程服务器（重点推荐）

integrate方式通过修服务器启动配置文件，随服务启动，这种方式比较稳定，而且能够全面启用YourKit的所有功能。

#### 线上环境

- CentOS release 6.3 64-Bit
- Java 1.7.0_79 HotSpot(TM) 64-Bit Server VM



#### 下载安装包

```shell
# wget https://www.yourkit.com/download/yjp-2017.02-b53.zip
# unzip yjp-2017.02-b53.zip
# cd yjp-2017.02
```



#### 确定服务进程号

```shell
# jps
2230 Resin
3959 Jps
```



#### Console连接进程

通过下面的命令来连接到Java进程。

```shell
# bin/yjp.sh -integrate
Choose server to integrate with:
1) Geronimo
2) GlassFish
3) JBoss / WildFly
4) Jetty
5) JRun 4
6) Resin 3.1/4
7) Tomcat 3–8
8) WebLogic 9 and newer
9) WebSphere Application Server 7 or newer
10) WebSphere Application Server V8.5 Liberty profile
11) Generic server (use if your server is not on the list)
Enter number which corresponds to your server (0 to exit) and press Enter:
>6
Please specify whether the server runs on a 32-bit JVM or a 64-bit JVM.
Hint: If you are not sure what to choose, choose "32-bit JVM". If with this choice the server does not start with profiling, re-run the integration and choose "64-bit Java" option.
1) 32-bit JVM
2) 64-bit JVM
>2
Resin configuration file (<RESIN_HOME>/conf/resin.xml or <RESIN_HOME>/conf/resin.conf):
>/home/work/bin/miui-sec-adv/resin/conf/resin.xml

Startup options configuration: step 1 of 5
Should option 'disablestacktelemetry' be specified?
1) Yes (recommended to minimize profiling overhead in production)
2) No
>2
Startup options configuration: step 2 of 5
Should option 'exceptions=disable' be specified?
1) Yes (recommended to minimize profiling overhead in production)
2) No
>1
Startup options configuration: step 3 of 5
Built-in probes:

1) Enabled: recommended for use in DEVELOPMENT; gives high level profiling results, but may add overhead
2) Disabled: recommended for use in PRODUCTION to minimise overhead, or for troubleshooting

Hint: It's recommended to choose #1 in development and #2 in production.
If choosing #1 makes profiling overhead big or there are startup issues, re-run the integration and choose #2.
>2
Startup options configuration: step 4 of 5
Should option 'delay=10000' be specified?
1) Yes (recommended)
2) No
>1
Startup options configuration: step 5 of 5
Please specify comma-separated list of additional startup options, or press Enter for no additional options:
>
A new config file is created:

/home/work/bin/miui-sec-adv/resin/conf/resin_yjp.xml

To profile the server:

1) [Recommended] Backup original 'resin.xml'
2) Rename 'resin_yjp.xml' to 'resin.xml'
3) Start the server
```

上面的操作执行完成后，会在操作中指定的resin配置文件目录生成`resin_yjp.xml`文件，接下来将该`resin_yjp.xml`重命名为`resin.xml`，并启动服务器。正常情况下，YourKit的Console程序便会随着Resin服务器自动启动，可以通过`lsof`命令确认一下。

```shell
# lsof -i:10001
COMMAND  PID USER   FD   TYPE     DEVICE SIZE/OFF NODE NAME
java    2389 work    8u  IPv4 3188835745      0t0  TCP *:scp-config (LISTEN)
```

同时，可以通过IP:PORT的方式在浏览器中查看YourKit Console服务的概况。

![YourKit Page](http://olno3yiqc.bkt.clouddn.com/blog/img/yourkit-page-integrate.png)



#### YourKit UI连接远程服务

打开YourKit UI，点击Connect to remote application，输入IP:PORT进行连接。

![YourKit UI Connect](http://olno3yiqc.bkt.clouddn.com/blog/img/yourkit-ui-connect-integrate.png)



连接成功后，进行性能分析界面，大功告成。

![YourKit性能分析界面](http://olno3yiqc.bkt.clouddn.com/blog/img/your-kit-home-integrate.png)
