---
title: "JVM配置参数-X与-XX的区别"
categories: ["JVM"]
tags: ["JVM", "JAVA"]
date: "2016-12-28T13:14:12+08:00"
publish: true
description: 启动JVM时通过指定的配置参数来指导虚拟机按照我们的要求提供服务，这一点对大多数的Java程序员来说已经是司空见惯。在指定配置参数时，会有-X和-XX两种形式，那么它们两者有什么区别呢，今天我想借这篇文章总结一下。
---

启动JVM时通过指定配置参数来指导虚拟机按照我们的要求提供服务，这一点对大多数的Java程序员来说已经是司空见惯。

在指定配置参数时，会有-X和-XX两种形式，那么它们两者有什么区别呢，今天我想借这篇文章总结一下。

下面是我们的某个Java项目在正式环境上启动JVM时的一个典型命令，在该命令中指定了各种启动参数：

```
java -Xmx15G -Xms10G -Xmn3G -Xss512k -XX:MaxPermSize=512M -XX:PermSize=512M -XX:+PrintFlagsFinal -XX:MaxTenuringThreshold=1 -XX:SurvivorRatio=23 -XX:TargetSurvivorRatio=80 -Xnoclassgc -XX:+UseParNewGC -XX:+UseConcMarkSweepGC -XX:CMSInitiatingOccupancyFraction=80 -XX:ParallelGCThreads=24 -XX:ConcGCThreads=24 -XX:+CMSParallelRemarkEnabled -XX:+CMSScavengeBeforeRemark -XX:+ExplicitGCInvokesConcurrent -XX:+UseTLAB -XX:TLABSize=64K, -verbose:gc -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCTimeStamps -XX:+PrintGCApplicationStoppedTime -Xloggc:./gc.log
```


Java HotSpot VM的官方文档中将启动参数分为如下两类：

配置 参数  | 类型 | 说明 | 举例
:--------: | :----------: | :--------- | :--------:
-X   | non-standard | 非标准参数。<br/><br/>这些参数不是虚拟机规范规定的。因此，不是所有VM的实现(如:HotSpot,JRockit,J9等)都支持这些配置参数。      | -Xmx、-Xms、-Xmn、-Xss
-XX  | not-stable   | 不稳定参数。<br/><br/>这些参数是虚拟机规范中规定的。这些参数指定虚拟机实例在运行时的各种行为，从而对虚拟机的运行时性能有很大影响。 | -XX:SurvivorRatio、-XX:+UseParNewGc

补充: -X和-XX两种参数都可能随着JDK版本的变更而发生变化，有些参数可以能会被废弃掉，有些参数的功能会发生改变，但是JDK官方不会通知开发者这些变化，需要使用者注意。

-XX参数被称为不稳定参数，是因为这类参数的设置会引起JVM运行时性能上的差异，配置得当可以提高JVM性能，配置不当则会使JVM出现各种问题, 甚至造成JVM崩溃。

国外有个哥们从HotSpot VM的源码里发现了934个此类型的配置参数，因此能对JVM做出很多组合配置，对JVM的调优也没有统一的标准，需要我们在实践中不断总结经验，并结合实际业务来进行操作，最终找到最适合当前业务的那些配置。

## 一些有用的-XX配置
对于-XX类型的配置选项，虚拟机规范有一些惯例，针对不同的平台虚拟机也会提供不同的默认值。

* 对于布尔(Boolean)类型的配置选项，通过`-XX:+<option>`来开启，通过`-XX:-<option>`来关闭。
* 对于数字(Numberic)类型的配置选项，通过`-XX:<option>=<number>`来配置。`<number>`后面可以携带单位字母，比如: 'k'或者'K'代表千字节，'m'或者'M'代表兆字节，'g'或者'G'代表千兆字节。
* 对于字符串(String)类型的配置选项，通过`-XX:<option>=<string>`来配置。这种配置通过用来指定文件，路径或者命令列表。

## 参考文献
1, [JVM Options - The complete reference](http://jvm-options.tech.xebia.fr/)

2, [Java HotSpot VM Options](http://www.oracle.com/technetwork/java/javase/tech/vmoptions-jsp-140102.html)

