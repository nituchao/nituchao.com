此文从用户角度出发，如果遇到OOM，该如何调参，因此不论述Spark框架层次引来的OOM。

## Full GC or GC limited or Heap Space
UI或者spark.log日中能见着：
```java
java.lang.OutOfMemoryError: GC overhead limit exceeded

java.lang.OutOfMemoryError: java heap space
```

或者gc.log中能见到Full GC的日志:

![Spark full GC log](http://olno3yiqc.bkt.clouddn.com/spark-full-gc-log.png)

## Spark内存模型
在讲如何调参时，先介绍一下Spark内寸模型：on-heap的统一动态内存模型

Spark框架主要由两处消耗heap的地方，Spark内部将其分成两个区：Storage和Execution(Execution部分主要用于ShuffleRead和ShuffleWrite)。
* Storage: 主要存RDD，Broadcast等。涉及的Spark操作：persist/cache/sc.broadcast等。
* Execution：主要用于Shuffle阶段，read shuffle/write shuffle阶段需要开buffer来做一些merge操作或者防止shuffle数据放内存原地爆炸。一般涉及的操作：XXXXByKey(reduceByKey，combineByKey等)/group/join等。

统一动态内存模型指的是将Storage和Execution的内存统一管理起来，两者的内存份额可动态调整，此消彼长，如下图所示：
1. 红色部分为Spark的内存份额，由参数spark.memary.fration控制。Spark的Storage内存或者Shuffle内存占用的是heap的老年代空间，老年代的占heap的比例约为0.66，如果老年代几乎用满，则会引发Full GC设置OOM，具体Google JVM的内存模型，在此不赘述。
2. 蓝色部分为可供用户使用的内存份额，也就是用户代码可使用的内存空间，此处也指老年代空间。
3，紫色部分是Spark保留份额。

![Spark 内存模型](http://olno3yiqc.bkt.clouddn.com/spark-memory-mode.png)

涉及的heap参数：

| 参数名 |	含义   | 默认值  |
|:-----:|:-----:|:------:|
| spark.memory.fraction | 存Block和Shuffle数据的memory 比例 | 0.55 |
| spark.memory.storageFraction | spark.memory.fraction中用来存Block的memory比例, 只是一个基准值, 非绝对值 | 0.5 |

## 调参
### Driver heap
Driver heap使用的量也可以分为三部分:

#### 1. 用户在Driver端口生成大对象, 比如创建了一个大的集合数据结构

解决思路:

1.1. 考虑将该大对象转化成Executor端加载. 例如调用sc.textFile/sc.hadoopFile等

1.2. 如若无法避免, 自我评估该大对象占用的内存, 相应增加driver-memory的值


#### 2. 从Executor端收集数据回Driver端, 比如Collect. 某个Stage中Executor端发回的所有数据量不能超过spark.driver.maxResultSize，默认1g. 如果用户增加该值, 请对应增加2*delta increase到Driver Memory, resultSize该值只是数据序列化之后的Size, 如果是Collect的操作会将这些数据反序列化收集, 此时真正所需内存需要膨胀2-5倍, 甚至10倍.

解决思路:

2.1. 本身不建议将大的数据从Executor端, collect回来. 建议将Driver端对collect回来的数据所做的操作, 转化成Executor端RDD操作.

2.2. 如若无法避免, 自我评collect需要的内存, 相应增加driver-memory的值

#### 3. Spark本身框架的数据消耗. 现在在Spark1.6版本之后主要由Spark UI数据消耗, 取决于作业的累计Task个数.
 
例子：
```java
Job aborted due to stage failure: Total size of serialized results of 51 tasks (1025.0 MB) is bigger than spark.driver.maxResultSize (1024.0 MB)
```

该Stage总计64个Task, 预计的Size为 1025MB/51 * 64 ... 调整maxResultSize 大于该值。

解决思路:

3.1. 考虑缩小大numPartitions的Stage的partition个数, 例如从HDFS load的partitions一般自动计算, 但是后续用户的操作中做了过滤等操作已经大大减少数据量, 此时可以缩小Parititions。

3.2. 通过参数spark.ui.retainedStages(默认1000)/spark.ui.retainedJobs(默认1000)控制.

3.3. 实在没法避免, 相应增加内存.

### Executor heap
UI 表现形式:

1. UI Task的失败原因显示: java.lang.OutOfMemoryError 

![java.lang.OutOfMemoryError](http://olno3yiqc.bkt.clouddn.com/spark-heap-ui1.png)

2. UI Task的失败原因显示: ExecutorLostFailure 和Executor exit code 为143. 

![ExecutorLostFailure和Executor exit code为143](http://olno3yiqc.bkt.clouddn.com/spark-heap-ui2.png)

3. UI Task的失败原因显示：ExecutorLostFailure和Executor Lost的原因是Executor heartbeat timed out
![Executor heartbeat timetou](http://olno3yiqc.bkt.clouddn.com/spark-heap-ui3.png)

只论述如果是用户相关的.

1. 数据相关, 例如用户单key对应的Values过多, 比如调用groupByKey或者对Value是集合类型的RDD[K, V]做reduceByKey或者AggregateByKey操作, 引起的OOM

** 解决思路: **

1.1. 控制Value的个数, 做截断. 很多情况是用户自身有异常数据导致.

1.2. 考虑对业务逻辑的RDD操作, 考虑其他方式的RDD实现, 避免统一处理所有的Values. 比如对Key做且分,类似keyA_1, keyA_2操作.

1.3. 降低spark.memory.fraction的值, 以此提高用户可用的内存空间. 注意spark.memory.fraction的至少保证在0.1. 降低该值会影响Spark的执行效率, 酌情减少。

1.4 增加 Exeutor-memory

2. 用户在RDD操作里创建了不容易释放的大对象, 例如集合操作中产生不易释放的对象。

解决思路:

1.1. 优化逻辑. 避免在一个RDD操作中实现大量集合操作, 可以尝试转化成多个RDD操作.

1.2. 降低spark.memory.fraction的值, 以此提高用户可用的内存空间. 注意spark.memory.fraction的至少保证在0.1, 降低该值会影响Spark的执行效率, 酌情减少。

1.3. 增加Executor-memory.

### 堆外内存

该部分内存主要用于程序的共享库、Perm Space、 线程Stack和一些Memory mapping等, 或者类C方式allocate object.

堆外内存在Spark中可以从逻辑上分成两种: 一种是DirectMemory, 一种是JVM Overhead(下面统称为off heap), 这两者在Spark中的大小分别由两个参数设置.

Spark中有哪些地方会消耗堆外内存, 会在后面详细讲述.

Direct Memory OOM的表现如下:

![Direct Memory OOM](http://olno3yiqc.bkt.clouddn.com/spark-direct-memory.png)

Executor Off heap超出被杀表现如下:

![Executor Off heap超出被杀](http://olno3yiqc.bkt.clouddn.com/spark-off-heap.png)

### Spark 可能出现Direct OOM or Off-Heap使用超出预期的涉及点:

* 用户代码 中带来的off heap使用不当, 例如加载文件资源次数过多, 且不正常关闭, 例如多次调用ClassLoader().getResourceAsStream

* Driver端：

拉取Executor端Task Result数据回Driver节点时, 此处消耗的DirectMemory内存 = conf.getInt("spark.resultGetter.threads", 4) * Task的ResultSize

* Executor端:
Executor可能消耗的情况如下:

1. Direct Memory, 拉取remote RDD Block时出现Direct OOM, 此时消耗的Direct Memory = 拉取的RDDBlockSize. （不够用时抛出Direct OOM）

Tips:

查看RDD Block Size步骤: SparkUI->Storage Tabs -> 看众多RDD中Memory或者Disk中的totalSize/cached Partitions中最大的RDD, 点进去看详情页, 然后对RDD的大小 按照Memory或者Disk排序, 找到最大的RDD Block

如下图标记处:

![spark max rdd](http://olno3yiqc.bkt.clouddn.com/spark-max-rdd.png)

2. Direct Memory, 拉取Shuffle数据时出现Direct OOM, 此时消耗的Direct Memory 通常= max(某个Shuffle Block的size, 50MB) (不够用时抛出 Direct OOM)

Tips: 可以在抛出该Direct OOM的Executor节点上检查是否有如下日志: Spark会在如果单个shuffleBlock的大小>1MB时输出该语句.

![spark shuffle block](http://olno3yiqc.bkt.clouddn.com/spark-shuffle-block.png)

还有一种预估的方式, 前一阶段Stage 对其内的每个Task的Shuffle Write排序, 找到最大的Shuffle Write / 下一阶段的task个数, 即为一个预估的shuffle Block大小.

3. Direct Memory, 还有一种情况是写Disk level的 RDD Block带来的额外Direct Memory消耗, 最多64MB * 3 (不够用时抛出Direct OOM)

4. off-heap, 读取local的Disk Level的RDD Block进行计算. 此时消耗的Off-heap内存 = 你stage计算流中会用到的Disk level RDDBlock 的size之和 (Executor 被Kill)

```java
此部分Size如第1点所示, 找到Disk中最大的RDD Block即可.
```

5. off-heap, 涉及到读Hbase时会消耗比较多的off-heap内存, 但这部分已经通过参数（spark.hadoop.hbase.ipc.client.connection.maxidletime）控制使用上限制在256MB.

## Spark off heap内存控制参数:

off heap的使用总量 = jvmOverhead(off heap) + directMemoryOverhead(direct memory) + otherMemoryOverhead

| 参数 | 描述 | 默认值 |
|:---:|:---:|:-----:|
| spark.yarn.executor.jvmMemoryOverhead | off heap 内存控制 | max(0.1 * executorMemory, 384MB) |
| spark.yarn.executor.directMemoryOverhead | Direct Memory的控制参数 | 256MB |
| spark.yarn.driver.jvmMemoryOverhead | 同Executor |  |
| spark.yarn.driver.directMemoryOverhead | 同Executor | |
| spark.yarn.executor.memoryOverhead | 统筹参数, 如果设置了该值m, 会自动按比例分配off heap给jvmOverhead和directMemory, 分配比例为jvmOverhead = max(0.1 * executorMemory, 384MB), directMemoryOverhead =m - jvmOverhead | 无 |
| spark.yarn.driver.memoryOverhead | 同Executor |  |

## 解决思路

合理的参数推荐:

一般推荐总值:

```java
spark.yarn.executor.directMemoryOverhead = 

{ if 存在memory level or disk level 的 block then  第1点的Size else 0 } +

{if Shuffle阶段抛出Direct OOM then 第2点的Size else 0} +

｛if 存在Disk level的Block then 第3点的192MB else 0｝ +

256MB


spark.yarn.executor.jvmOverhead = 
{ if 存在disk level的Block then (第4点的Size * 2)  else 0 } + 
{ if 存在读Hbase then 256MB else 0} +
max(executor-memory * 0.1, 384)
// 如果没有Executor表现为off-heap使用超出, 则不需要手动调整.
```