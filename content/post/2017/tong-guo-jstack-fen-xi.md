---
title: "jstack命令"
date: "2017-02-28T19:01:58+08:00"
categories: ["Jtool"]
tags: ["Java"]
---

Java程序在操作系统上是以单进程、多线程的形式运行。



```bash
[work@zc-stage1-miui-sec02 ~]$ jstack
Usage:
    jstack [-l] <pid>
        (to connect to running process)
    jstack -F [-m] [-l] <pid>
        (to connect to a hung process)
    jstack [-m] [-l] <executable> <core>
        (to connect to a core file)
    jstack [-m] [-l] [server_id@]<remote server IP or hostname>
        (to connect to a remote debug server)

Options:
    -F  to force a thread dump. Use when jstack <pid> does not respond (process is hung)
    -m  to print both java and native frames (mixed mode)
    -l  long listing. Prints additional information about locks
    -h or -help to print this help message
```



## jstack参数说明

1. 连接到运行中的进程

   "jstack pid"，pid为进程号，可以通过jps或者top命令查到。

   命令执行成功则堆栈信息打印在控制台，可以通过"jstack 7023 > stack.log"这种方式将内容输出文件。

   导出的文本中包含线程号，线程号状态，线程调用栈等信息，结合ps命令中查询出的线程号，可以分析出CPU使用率比较高的线程，以及该线程中的调用堆栈，进而可以定位到项目代码。

   ```
   Thread 1091: (state = BLOCKED)
    - sun.misc.Unsafe.park(boolean, long) @bci=0 (Compiled frame; information may be imprecise)
    - java.util.concurrent.locks.LockSupport.park() @bci=5, line=315 (Interpreted frame)
    - com.caucho.env.thread2.ResinThread2.park() @bci=29, line=196 (Compiled frame)
    - com.caucho.env.thread2.ResinThread2.runTasks() @bci=65, line=147 (Compiled frame)
    - com.caucho.env.thread2.ResinThread2.run() @bci=15, line=118 (Interpreted frame)


   Thread 1089: (state = BLOCKED)
    - sun.misc.Unsafe.park(boolean, long) @bci=0 (Compiled frame; information may be imprecise)
    - java.util.concurrent.locks.LockSupport.park() @bci=5, line=315 (Interpreted frame)
    - com.caucho.env.thread2.ResinThread2.park() @bci=29, line=196 (Compiled frame)
    - com.caucho.env.thread2.ResinThread2.runTasks() @bci=65, line=147 (Compiled frame)
    - com.caucho.env.thread2.ResinThread2.run() @bci=15, line=118 (Interpreted frame)


   Thread 1088: (state = IN_NATIVE)
    - java.net.SocketInputStream.socketRead0(java.io.FileDescriptor, byte[], int, int, int) @bci=0 (Compiled frame; information may be imprecise)
    - java.net.SocketInputStream.read(byte[], int, int, int) @bci=79, line=150 (Compiled frame)
    - java.net.SocketInputStream.read(byte[], int, int) @bci=11, line=121 (Compiled frame)
    - java.net.SocketInputStream.read(byte[]) @bci=5, line=107 (Compiled frame)
    - redis.clients.util.RedisInputStream.ensureFill() @bci=20, line=195 (Compiled frame)
    - redis.clients.util.RedisInputStream.readByte() @bci=1, line=40 (Compiled frame)
    - redis.clients.jedis.Protocol.process(redis.clients.util.RedisInputStream) @bci=1, line=141 (Compiled frame)
    - redis.clients.jedis.Protocol.read(redis.clients.util.RedisInputStream) @bci=1, line=205 (Compiled frame)
    - redis.clients.jedis.Connection.readProtocolWithCheckingBroken() @bci=4, line=297 (Compiled frame)
    - redis.clients.jedis.Connection.getBinaryBulkReply() @bci=15, line=216 (Compiled frame)
    - redis.clients.jedis.Connection.getBulkReply() @bci=1, line=205 (Compiled frame)
    - redis.clients.jedis.Jedis.get(java.lang.String) @bci=27, line=101 (Compiled frame)
    - redis.clients.jedis.JedisCluster$3.execute(redis.clients.jedis.Jedis) @bci=5, line=79 (Compiled frame)
    - redis.clients.jedis.JedisCluster$3.execute(redis.clients.jedis.Jedis) @bci=2, line=76 (Compiled frame)
    - redis.clients.jedis.JedisClusterCommand.runWithRetries(byte[], int, boolean, boolean) @bci=78, line=119 (Compiled frame)
    - redis.clients.jedis.JedisClusterCommand.run(java.lang.String) @bci=25, line=30 (Compiled frame)
    - redis.clients.jedis.JedisCluster.get(java.lang.String) @bci=18, line=81 (Compiled frame)
    - com.xiaomi.miui.sec.service.RedisCacheService$14.call(redis.clients.jedis.RedisCluster) @bci=5, line=667 (Compiled frame)
    - com.xiaomi.miui.sec.service.RedisCacheService$14.call(java.lang.Object) @bci=5, line=663 (Compiled frame)
    - com.xiaomi.miui.cache.rediscluster.DefaultRedisClusterCache.get(java.lang.Object, com.xiaomi.miui.cache.rediscluster.RedisClusterCallable) @bci=22, line=68 (Compiled frame)
    - com.xiaomi.miui.sec.service.RedisCacheService.getSettingAdv(java.lang.String, java.lang.String, java.lang.String) @bci=49, line=663 (Compiled frame)
    - com.xiaomi.miui.sec.service.CacheService.getSettingAdv(java.lang.String, java.lang.String, java.lang.String) @bci=7, line=113 (Compiled frame)
    - com.xiaomi.miui.sec.bizLogic.SettingBiz.postHandlerMiCom(net.sf.json.JSONObject, com.xiaomi.miui.sec.thrift.Device, net.paoding.rose.web.Invocation) @bci=55, line=119 (Compiled frame)
    - com.xiaomi.miui.sec.bizLogic.SettingBiz.postHandler(net.sf.json.JSONObject, com.xiaomi.miui.sec.thrift.Device, net.paoding.rose.web.Invocation) @bci=118, line=65 (Compiled frame)
    - com.xiaomi.miui.sec.bizLogic.BasicBiz.mainHandler(net.paoding.rose.web.Invocation) @bci=29, line=59 (Compiled frame)
    - com.xiaomi.miui.sec.controllers.InfoController.setting(net.paoding.rose.web.Invocation, java.lang.String) @bci=73, line=252 (Compiled frame)
    - sun.reflect.GeneratedMethodAccessor31.invoke(java.lang.Object, java.lang.Object[]) @bci=48 (Compiled frame)
    - sun.reflect.DelegatingMethodAccessorImpl.invoke(java.lang.Object, java.lang.Object[]) @bci=6, line=43 (Compiled frame)
    - java.lang.reflect.Method.invoke(java.lang.Object, java.lang.Object[]) @bci=57, line=606 (Compiled frame)
    

   ```

   ​

## jstack分析java线程的CPU使用率和使用时长



## jstack分析分析已有的javacore文件



## jstack连接到远程调试服务器进行分析