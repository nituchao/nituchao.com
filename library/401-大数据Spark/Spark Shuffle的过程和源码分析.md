---
"categories": ["Spark"],
"tags": ["Spark"],
"date": "2014-06-22T13:32:00+08:00",
"title": "Spark运行模式研究"

---
## Spark Shuffle 的过程和源码分析

<!-- toc -->

### Shuffle基本概念与常见实现方式
{% em %}shuffle，是一个算子，表达的是多对多的依赖关系。{% endem %}在类MapReduce计算框架中，是连接Map阶段和Reduce阶段的纽带，即每个Reduce Task从每个Map Task产生的数据中读取一片数据，极限情况下可能触发M*R个数据拷贝通道（M是Map Task数目，R是Reduce Task数目）。

通常shuffle分为两部分：{% em type=red %}Map阶段的数据准备和Reduce阶段的数据拷贝。{% endem %}

首先，Map阶段需根据Reduce阶段的Task数量决定每个Map Task输出的数据分片数目，有多种方式存放这些数据分片：

1） 保存在内存中或者磁盘上（Spark和MapReduce都存放在磁盘上）；

2） 每个分片一个文件（现在Spark采用的方式，若干年前MapReduce采用的方式），或者所有分片放到一个数据文件中，外加一个索引文件记录每个分片在数据文件中的偏移量（现在MapReduce采用的方式）。

在Map端，不同的数据存放方式各有优缺点和适用场景。{% em %}一般而言，shuffle在Map端的数据要存储到磁盘上，以防止容错触发重算带来的庞大开销（如果保存到Reduce端内存中，一旦Reduce Task挂掉了，所有Map Task需要重算）。{% endem %}

但数据在磁盘上存放方式有多种可选方案，在MapReduce前期设计中，采用了现在Spark的方案（目前一直在改进），每个Map Task为每个Reduce Task产生一个文件，该文件只保存特定Reduce Task需处理的数据，这样会产生M*R个文件，如果M和R非常庞大，比如均为1000，则会产生100w个文件，产生和读取这些文件会产生大量的随机IO，效率非常低下。解决这个问题的一种直观方法是减少文件数目，常用的方法有：1) 将一个节点上所有Map产生的文件合并成一个大文件（MapReduce现在采用的方案），2) 每个节点产生{(slot数目)*R}个文件（Spark优化后的方案）。对后面这种方案简单解释一下：不管是MapReduce 1.0还是Spark，每个节点的资源会被抽象成若干个slot，由于一个Task占用一个slot，因此slot数目可看成是最多同时运行的Task数目。如果一个Job的Task数目非常多，限于slot数目有限，可能需要运行若干轮。这样，只需要由第一轮产生{(slot数目)*R}个文件，后续几轮产生的数据追加到这些文件末尾即可。因此，后一种方案可减少大作业产生的文件数目。

在Reduce端，各个Task会并发启动多个线程同时从多个Map Task端拉取数据。由于Reduce阶段的主要任务是对数据进行按组规约。也就是说，需要将数据分成若干组，以便以组为单位进行处理。大家知道，分组的方式非常多，常见的有：Map/HashTable（key相同的，放到同一个value list中）和Sort（按key进行排序，key相同的一组，经排序后会挨在一起），这两种方式各有优缺点，第一种复杂度低，效率高，但是需要将数据全部放到内存中，第二种方案复杂度高，但能够借助磁盘（外部排序）处理庞大的数据集。Spark前期采用了第一种方案，而在最新的版本中加入了第二种方案， MapReduce则从一开始就选用了基于sort的方案。

### MapReduce Shuffle发展史
【阶段1】：MapReduce Shuffle的发展也并不是一马平川的，刚开始（0.10.0版本之前）{% em %}采用了“每个Map Task产生R个文件”的方案{% endem %}，前面提到，该方案会产生大量的随机读写IO，对于大数据处理而言，非常不利。

【阶段2】：为了避免Map Task产生大量文件，[HADOOP-331](https://issues.apache.org/jira/browse/HADOOP-331)尝试对该方案进行优化，优化方法：{% em %}为每个Map Task提供一个`环形buffer`，一旦buffer满了后，则将内存数据spill到磁盘上（外加一个索引文件，保存每个`partition的偏移量`），最终合并产生的这些`spill文件`，同时创建一个索引文件，保存每个partition的偏移量。{% endem %}

说明：这个阶段并没有对shuffle架构做调成，只是对shuffle的环形buffer进行了优化。在Hadoop 2.0版本之前，对MapReduce作业进行参数调优时，Map阶段的buffer调优非常复杂的，涉及到多个参数，这是由于buffer被切分成两部分使用：一部分保存索引（比如parition、key和value偏移量和长度），一部分保存实际的数据，这两段buffer均会影响spill文件数目，因此，需要根据数据特点对多个参数进行调优，非常繁琐。而[MAPREDUCE-64](https://issues.apache.org/jira/browse/MAPREDUCE-64)则解决了该问题，该方案让索引和数据共享一个环形缓冲区，不再将其分成两部分独立使用，这样只需设置一个参数控制spill频率。

【阶段3（进行中）】：{% em %}目前shuffle被当做一个子阶段被嵌到Reduce阶段中的。{% endem %}由于MapReduce模型中，Map Task和Reduce Task可以同时运行，因此一个作业前期启动的Reduce Task将一直处于shuffle阶段，直到所有Map Task运行完成，而在这个过程中，Reduce Task占用着资源，但这部分资源利用率非常低，基本上只使用了IO资源。为了提高资源利用率，一种非常好的方法是将shuffle从Reduce阶段中独立处理，变成一个独立的阶段/服务，由专门的shuffler service负责数据拷贝，目前百度已经实现了该功能（准备开源？），且收益明显，具体参考：[MAPREDUCE-2354](https://issues.apache.org/jira/browse/MAPREDUCE-2354)。

{% em %}补充:{% endem %} 在MAPREDUCE-2354这个jira中，作者列举了Shullfe的以下几个问题，想要表达的核心思想是{% em type=red %}当前的Shuffe过程与Reduce紧密集成在一起，而Shuffe过程是一个高I/O的操作，而Reduce则是一个高CPU和高内存的操作，两者的集成造成了系统瓶颈，该作者建议将Shuffe过程从Reduce过程中解耦出来做成一个单独的service。{% endem %}

> Our study shows that shuffle is a performance bottleneck of mapreduce computing. There are some problems of shuffle:

> (1)Shuffle and reduce are tightly-coupled, usually shuffle phase doesn't consume too much memory and CPU, so theoretically, reducetasks's slot can be used for other computing tasks when copying data from maps. This method will enhance cluster utilization. Furthermore, should shuffle be separated from reduce? Then shuffle will not use reduce's slot,we need't distinguish between map slots and reduce slots at all.

> (2)For large jobs, shuffle will use too many network connections, Data transmitted by each network connection is very little, which is inefficient. From 0.21.0 one connection can transfer several map outputs, but i think this is not enough. Maybe we can use a per node shuffle client progress(like tasktracker) to shuffle data for all reduce tasks on this node, then we can shuffle more data trough one connection.

> (3)Too many concurrent connections will cause shuffle server do massive random IO, which is inefficient. Maybe we can aggregate http request(like delay scheduler), then random IO will be sequential.

> (4)How to manage memory used by shuffle efficiently. We use buddy memory allocation, which will waste a considerable amount of memory.

> (5)If shuffle separated from reduce, then we must figure out how to do reduce locality?

> (6)Can we store map outputs in a Storage system(like hdfs)?

> (7)Can shuffle be a general data transfer service, which not only for map/reduce paradigm?

### Spark Shuffle 发展史
目前看来，Spark Shuffle的发展史与MapReduce发展史非常类似。{% em %}初期Spark在Map阶段采用了“每个Map Task产生R个文件”的方法，在Reduce阶段采用了map分组方法，但随Spark变得流行，用户逐渐发现这种方案在处理大数据时存在严重瓶颈问题，因此尝试对Spark进行优化和改进。{% endem %} 相关链接有：[External Sorting for Aggregator and CoGroupedRDDs](https://github.com/apache/incubator-spark/pull/303)，“Optimizing Shuffle Performance in Spark”，[Consolidating Shuffle Files in Spark](https://spark-project.atlassian.net/browse/SPARK-751)，优化动机和思路与MapReduce非常类似。

Spark在前期设计中过多依赖于内存，使得一些运行在MapReduce之上的大作业难以直接运行在Spark之上（可能遇到OOM问题）。{% em %}目前Spark在处理大数据集方面尚不完善，用户需根据作业特点选择性的将一部分作业迁移到Spark上，而不是整体迁移。{% endem %} 随着Spark的完善，很多内部关键模块的设计思路将变得与MapReduce升级版Tez非常类似。

![Spark Shuffle流程图](http://olno3yiqc.bkt.clouddn.com/spark%20shuffle%E8%BF%87%E7%A8%8B.jpg)

** 过程描述 **
* 首先每一个Mapper会根据Reducer的数量创建出相应的bucket，bucket的数量是M×R，其中M是Map的个数，R是Reduce的个数。
* 其次Mapper产生的结果会根据设置的partition算法填充到每个bucket中去。这里的partition算法是可以自定义的，当然默认的算法是根据key哈希到不同的bucket中去。
* Reducer启动时，它会根据自己task的id和所依赖的Mapper的id从远端或是本地的block manager中取得相应的bucket作为Reducer的输入进行处理。

这里的`bucket`是一个抽象概念，在实现中每个`bucket`可以对应一个文件，可以对应文件的一部分或是其他等。

#### Spark 1.1 时代的Shuffle

#### Spark 1.2 时代的Shuffle
对于Shuffle来说，Spark Shuffle-1.2.0是个重要的分水岭，从这个版本开始Spark的Shuffle由`Hash Based Shuffle`升级成了`Sort Based Shuffle。`即`spark.shuffle.manager`从Hash换成了Sort。不同形式的Shuffle逻辑主要是ShuffleManager的实现类不同。

[Spark-1.2分支代码SparkEnv.scala:285](https://github.com/apache/spark/blob/branch-1.2/core/src/main/scala/org/apache/spark/SparkEnv.scala):
{% ace edit=false, lang='scala', theme='monokai' %}
    // Let the user specify short names for shuffle managers
    val shortShuffleMgrNames = Map(
      "hash" -> "org.apache.spark.shuffle.hash.HashShuffleManager",
      "sort" -> "org.apache.spark.shuffle.sort.SortShuffleManager")
    val shuffleMgrName = conf.get("spark.shuffle.manager", "sort")
    val shuffleMgrClass = shortShuffleMgrNames.getOrElse(shuffleMgrName.toLowerCase, shuffleMgrName)
    val shuffleManager = instantiateClass[ShuffleManager](shuffleMgrClass)

    val shuffleMemoryManager = new ShuffleMemoryManager(conf)

    val blockTransferService =
      conf.get("spark.shuffle.blockTransferService", "netty").toLowerCase match {
        case "netty" =>
          new NettyBlockTransferService(conf, securityManager, numUsableCores)
        case "nio" =>
          new NioBlockTransferService(conf, securityManager)
      }
      
    val blockManagerMaster = new BlockManagerMaster(registerOrLookup(
      "BlockManagerMaster",
      new BlockManagerMasterActor(isLocal, conf, listenerBus)), conf, isDriver)

    // NB: blockManager is not valid until initialize() is called later.
    val blockManager = new BlockManager(executorId, actorSystem, blockManagerMaster,
      serializer, conf, mapOutputTracker, shuffleManager, blockTransferService, securityManager,
      numUsableCores)
      
{% endace %}

由上面的代码可以清楚的看到，在Spark-1.2.0版本中，Spark Shuffle管理器有"hash"和"sort"两种，其中"sort"是默认管理器，可以使用参数`spark.shuffle.manager`来变更管理器类型。

Shuffle的操作要消耗大量的I/O资源，在Shuffle中块传输服务提供了`netty`和`nio`两种。

#### Spark 1.4 时代的Shuffle
从spark-1.4.0开始，Spark Shuffle提供三种Shuffle管理器:
* hash : org.apache.spark.shuffle.hash.HashShuffleManager
* sort : org.apache.spark.shuffle.hash.SortShuffleManager
* tungsten-sort : org.spark.shuffle.unsafe.UnsafeShuffleManager

其中，`tungsten-sort`是第一次提出，核心目的是为了对shuffle进行优化。

`tungsten-sort`的实现类是`org.spark.shuffle.unsafe.UnsafeShuffleManager`，原因是由于该实现类使用了很多JDK中不安全API。

`UnsafeShuffleManager`类的实现和`SortShuffleManager`非常类似。在基于排序的shuffle中，输入记录按照他们的分区编号(partition ids)进行排序，然后写到对应的map输出文件。reduce进程接下来会读取(fetch)这些map输出文件。当map输出文件因为过大而无法完全放在内存时，这些文件会被spill到磁盘上去，多个spill到磁盘上的文件最终会进行合并。`UnsafeShuffleManager`对上面的过程进行了以下几点优化:
* 它的排序操作针对序列化后的二级制数据，而不是Java对象，这可以降低内存和GC的消耗。
* 提供cache-efficient sorter，使用一个8bytes的指针，把排序转化成了一个指针数组的排序。
* 溢出到磁盘的文件的合并过程也无需反序列化即可完成
* 溢出到磁盘的文件压缩后可以进行高效的数据传输。

这些优化的实现导致引入了一个新的内存管理模型，类似OS的Page，对应的实际数据结构为MemoryBlock,支持off-heap 以及 in-heap 两种模式。为了能够对Record 在这些MemoryBlock进行定位，引入了Pointer（指针）的概念。

Sort Based Shuffle里存储数据的对象PartitionedAppendOnlyMap,这是一个放在JVM heap里普通对象，在Tungsten-sort中，他被替换成了类似操作系统内存页的对象。如果你无法申请到新的Page,这个时候就要执行spill操作，也就是写入到磁盘的操作。具体触发条件，和Sort Based Shuffle 也是类似的。

当且仅当下面条件都满足时，才会使用新的Shuffle方式：

* Shuffle dependency 不能带有aggregation 或者输出需要排序
* Shuffle 的序列化器需要是 KryoSerializer 或者 Spark SQL's 自定义的一些序列化方式.
* Shuffle 文件的数量不能大于 16777216
* 序列化时，单条记录不能大于 128 MB

可以看到，能使用的条件还是挺苛刻的，更详细的介绍请移步[探索Spark Tungsten的秘密](https://github.com/hustnn/TungstenSecret/tree/master)


#### Spark 1.5 时代的Shuffle

#### Spark 1.6 时代的Shuffle


[Spark-1.6分支代码SparkEnv.scala:285](https://github.com/apache/spark/blob/branch-1.2/core/src/main/scala/org/apache/spark/SparkEnv.scala):
{% ace edit=false, lang='scala', theme='monokai' %}
    // Let the user specify short names for shuffle managers
    val shortShuffleMgrNames = Map(
      "hash" -> "org.apache.spark.shuffle.hash.HashShuffleManager",
      "sort" -> "org.apache.spark.shuffle.sort.SortShuffleManager",
      "tungsten-sort" -> "org.apache.spark.shuffle.sort.SortShuffleManager")
    val shuffleMgrName = conf.get("spark.shuffle.manager", "sort")
    val shuffleMgrClass = shortShuffleMgrNames.getOrElse(shuffleMgrName.toLowerCase, shuffleMgrName)
    val shuffleManager = instantiateClass[ShuffleManager](shuffleMgrClass)

    val useLegacyMemoryManager = conf.getBoolean("spark.memory.useLegacyMode", false)
    val memoryManager: MemoryManager =
      if (useLegacyMemoryManager) {
        new StaticMemoryManager(conf, numUsableCores)
      } else {
        UnifiedMemoryManager(conf, numUsableCores)
      }

    val blockTransferService = new NettyBlockTransferService(conf, securityManager, numUsableCores)

    val blockManagerMaster = new BlockManagerMaster(registerOrLookupEndpoint(
      BlockManagerMaster.DRIVER_ENDPOINT_NAME,
      new BlockManagerMasterEndpoint(rpcEnv, isLocal, conf, listenerBus)),
      conf, isDriver)

    // NB: blockManager is not valid until initialize() is called later.
    val blockManager = new BlockManager(executorId, rpcEnv, blockManagerMaster,
      serializer, conf, memoryManager, mapOutputTracker, shuffleManager,
      blockTransferService, securityManager, numUsableCores)

    val broadcastManager = new BroadcastManager(isDriver, conf, securityManager)
{% endace %}


### Spark Shuffle Wrirte
在Spark 0.6和0.7的版本中，对于shuffle数据的存储是以文件的方式存储在block manager中，与rdd.persist(StorageLevel.DISk_ONLY)采取相同的策略，可以参看：

{% ace edit=false, lang='scala', theme='monokai' %}
override def run(attemptId: Long): MapStatus = {
  val numOutputSplits = dep.partitioner.numPartitions
    // Partition the map output.
    val buckets = Array.fill(numOutputSplits)(new ArrayBuffer[(Any, Any)])
    for (elem <- rdd.iterator(split, taskContext)) {
      val pair = elem.asInstanceOf[(Any, Any)]
      val bucketId = dep.partitioner.getPartition(pair._1)
      buckets(bucketId) += pair
    }
    ...
    val blockManager = SparkEnv.get.blockManager
    for (i <- 0 until numOutputSplits) {
      val blockId = "shuffle_" + dep.shuffleId + "_" + partition + "_" + i
      // Get a Scala iterator from Java map
      val iter: Iterator[(Any, Any)] = buckets(i).iterator
      val size = blockManager.put(blockId, iter, StorageLevel.DISK_ONLY, false)
      totalBytes += size
    }
}
{% endace %}

可以看到Spark在每一个Mapper中为每个Reducer创建一个bucket，并将RDD计算结果放进bucket中。需要注意的是每个bucket是一个ArrayBuffer，也就是说{% em %}Map的输出结果是会先存储在内存。{% endem %}

接着Spark会将ArrayBuffer中的Map输出结果写入block manager所管理的磁盘中，这里文件的命名方式为： `shuffle_ + shuffleid + "_" + map partition id + "_" + shuffle partition id`。

早期的shuffle write有两个比较大的问题:
* Map的输出必须先全部存储到内存中，然后写入磁盘。这对内存是一个非常大的开销，当内存不足以存储所有的Map output时就会出现OOM。
* 每一个Mapper都会产生Reducer number个shuffle文件，如果Mapper个数是1k，Reducer个数也是1k，那么就会产生1M个shuffle文件，这对于文件系统是一个非常大的负担。同时在shuffle数据量不大而shuffle文件又非常多的情况下，随机写也会严重降低IO的性能。

在Spark 0.8版本中，shuffle write采用了与RDD block write不同的方式，同时也为shuffle write单独创建了ShuffleBlockManager，部分解决了0.6和0.7版本中遇到的问题。

首先我们来看一下Spark 0.8的具体实现:

{% ace edit=false, lang='scala', theme='monokai' %}
override def run(attemptId: Long): MapStatus = {
  ...
  val blockManager = SparkEnv.get.blockManager
  var shuffle: ShuffleBlocks = null
  var buckets: ShuffleWriterGroup = null
  try {
    // Obtain all the block writers for shuffle blocks.
    val ser = SparkEnv.get.serializerManager.get(dep.serializerClass)
    shuffle = blockManager.shuffleBlockManager.forShuffle(dep.shuffleId, numOutputSplits, ser)
    buckets = shuffle.acquireWriters(partition)
    // Write the map output to its associated buckets.
    for (elem <- rdd.iterator(split, taskContext)) {
      val pair = elem.asInstanceOf[Product2[Any, Any]]
      val bucketId = dep.partitioner.getPartition(pair._1)
      buckets.writers(bucketId).write(pair)
    }
    // Commit the writes. Get the size of each bucket block (total block size).
    var totalBytes = 0L
    val compressedSizes: Array[Byte] = buckets.writers.map { writer:   BlockObjectWriter =>
      writer.commit()
      writer.close()
      val size = writer.size()
      totalBytes += size
      MapOutputTracker.compressSize(size)
    }
    ...
  } catch { case e: Exception =>
    // If there is an exception from running the task, revert the partial writes
    // and throw the exception upstream to Spark.
    if (buckets != null) {
      buckets.writers.foreach(_.revertPartialWrites())
    }
    throw e
  } finally {
    // Release the writers back to the shuffle block manager.
    if (shuffle != null && buckets != null) {
      shuffle.releaseWriters(buckets)
    }
    // Execute the callbacks on task completion.
    taskContext.executeOnCompleteCallbacks()
    }
  }
}
{% endace %}

在这个版本中为`shuffle write`添加了一个新的类`ShuffleBlockManager`，由`ShuffleBlockManager`来分配和管理`bucket`。{% em %}同时ShuffleBlockManager为每一个bucket分配一个DiskObjectWriter，每个write handler拥有默认100KB的缓存，使用这个write handler将Map output写入文件中。{% endem %} 可以看到现在的写入方式变为buckets.writers(bucketId).write(pair)，也就是说{% em %}Map output的key-value pair是逐个写入到磁盘而不是预先把所有数据存储在内存中在整体flush到磁盘中去。{% endem %}

`ShuffleBlockManager`的代码如下所示:

{% ace edit=false, lang='scala', theme='monokai' %}
class ShuffleBlockManager(blockManager: BlockManager) {
  def forShuffle(shuffleId: Int, numBuckets: Int, serializer: Serializer): ShuffleBlocks = {
    new ShuffleBlocks {
      // Get a group of writers for a map task.
      override def acquireWriters(mapId: Int): ShuffleWriterGroup = {
        val bufferSize = System.getProperty("spark.shuffle.file.buffer.kb", "100").toInt * 1024
        val writers = Array.tabulate[BlockObjectWriter](numBuckets) { bucketId =>
          val blockId = ShuffleBlockManager.blockId(shuffleId, bucketId, mapId)
          blockManager.getDiskBlockWriter(blockId, serializer, bufferSize)
        }
        new ShuffleWriterGroup(mapId, writers)
      }
      override def releaseWriters(group: ShuffleWriterGroup) = {
        // Nothing really to release here.
      }
    }
  }
}
{% endace %}

{% em %}Spark 0.8显著减少了shuffle的内存压力，现在Map output不需要先全部存储在内存中，再flush到硬盘，而是record-by-record写入到磁盘中。{% endem %} 同时对于shuffle文件的管理也独立出新的ShuffleBlockManager进行管理，而不是与rdd cache文件在一起了。

但是这一版Spark 0.8的shuffle write仍然有两个大的问题没有解决：
* 首先依旧是shuffle文件过多的问题，产生的FileSegment过多，{% em %}共产生M x R个blockFiles{% endem %}, Spark job 的 M 和 R 都很大，因此磁盘上会存在大量的数据文件. Shuffle文件过多一是会造成文件系统的压力过大，二是会降低IO的吞吐量。每个ShuffleMapTask包含R个缓冲区，R = reducer 个数（也就是下一个 stage 中 task 的个数），缓冲区被称为 bucket，其大小为spark.shuffle.file.buffer.kb 每个bucket里的数据被不断写入磁盘形成ShuffleBlockFile(简称 FileSegment), 之后reducer会fetch属于自己的FileSegment，进入shuffle read阶段。
* 其次虽然Map output数据不再需要预先在内存中evaluate显著减少了内存压力，但是新引入的DiskObjectWriter所带来的buffer开销也是一个不容小视的内存开销。假定我们有1k个Mapper和1k个Reducer，那么就会有1M个bucket，于此同时就会有1M个write handler，而每一个write handler默认需要100KB内存，那么总共需要100GB的内存。这样的话仅仅是buffer就需要这么多的内存，内存的开销是惊人的。{% em %}当然实际情况下这1k个Mapper是分时运行的话，所需的内存就只有cores reducer numbers 100KB大小了。但是reducer数量很多的话，这个buffer的内存开销也是蛮厉害的。{% endem %}

** {% em %}为了解决shuffle文件过多的情况， Spark 0.8.1引入了新的shuffle consolidation，以期显著减少shuffle文件的数量。{% endem %} **

如图:
![Spark 0.8.1版本引入shuffle consolidation来减少shuffle文件的数量](http://olno3yiqc.bkt.clouddn.com/Spark%200.8.1%E7%89%88%E6%9C%AC%E5%BC%95%E5%85%A5shuffle%20consolidation%E6%9D%A5%E5%87%8F%E5%B0%91shuffle%E6%96%87%E4%BB%B6%E7%9A%84%E6%95%B0%E9%87%8F.jpg)

可以明显看出，{% em %}在一个`CPU core`上连续执行的 ShuffleMapTasks 可以共用一个输出文件 ShuffleFile。{% endem %}先执行完的 ShuffleMapTask 形成 ShuffleBlock i，后执行的 ShuffleMapTask 可以将输出数据直接追加到 ShuffleBlock i 后面，形成 ShuffleBlock i'，每个 ShuffleBlock 被称为 FileSegment。下一个 stage 的 reducer 只需要 fetch 整个 ShuffleFile 就行了。这样，每个 worker 持有的文件数降为 cores * R。{% em %}FileConsolidation 功能可以通过`spark.shuffle.consolidateFiles=true`来开启。{% endem %}

假定该job有4个Mapper和4个Reducer，有2个core，也就是能并行运行两个task。我们可以算出Spark的shuffle write共需要16个bucket，也就有了16个write handler。在之前的Spark版本中，每一个bucket对应的是一个文件，因此在这里会产生16个shuffle文件。

而在shuffle consolidation中每一个bucket并非对应一个文件，而是对应文件中的一个segment，同时shuffle consolidation所产生的shuffle文件数量与Spark core的个数也有关系。在上面的图例中，job的4个Mapper分为两批运行，在第一批2个Mapper运行时会申请8个bucket，产生8个shuffle文件；{% em %}而在第二批Mapper运行时，申请的8个bucket并不会再产生8个新的文件，而是追加写到之前的8个文件后面，这样一共就只有8个shuffle文件，而在文件内部这有16个不同的segment。{% endem %} 因此从理论上讲shuffle consolidation所产生的shuffle文件数量为C×R，其中C是Spark集群的core number，R是Reducer的个数。

{% em %}需要注意的是当 M=C时shuffle consolidation所产生的文件数和之前的实现是一样的。{% endem %}

Shuffle consolidation显著减少了shuffle文件的数量，解决了之前版本一个比较严重的问题，但是writer handler的buffer开销过大依然没有减少，若要减少writer handler的buffer开销，我们只能减少Reducer的数量，但是这又会引入新的问题，下文将会有详细介绍。

讲完了shuffle write的进化史，接下来要讲一下shuffle fetch了，同时还要讲一下Spark的aggregator，这一块对于Spark实际应用的性能至关重要。

问题2暂时还没有好的方法解决，因为写磁盘终究是要开缓冲区的，缓冲区太小会影响 IO 速度。

### Spark Shuffle Read 

先看一张包含 ShuffleDependency 的物理执行图，来自 reduceByKey：

![reduceByKey的物理执行过程](http://olno3yiqc.bkt.clouddn.com/reduceByKey%E7%9A%84%E7%89%A9%E7%90%86%E6%89%A7%E8%A1%8C%E8%BF%87%E7%A8%8B.jpg)


** 问题 ** 

很自然地，要计算 `ShuffleRDD` 中的数据，必须先把 `MapPartitionsRDD` 中的数据 `fetch` 过来。那么问题就来了：在什么时候 fetch，parent stage 中的一个 ShuffleMapTask 执行完还是等全部 ShuffleMapTasks 执行完？
* 边fetch边处理还是一次性fetch完再处理？
* fetch 来的数据存放到哪里？
* 怎么获得要 fetch 的数据的存放位置？

** 解决 **

* 在什么时候fetch?
> 当 parent stage 的所有 ShuffleMapTasks 结束后再 fetch。理论上讲，一个 ShuffleMapTask 结束后就可以 fetch，但是为了迎合 stage 的概念（即一个 stage 如果其 parent stages 没有执行完，自己是不能被提交执行的），还是选择全部 ShuffleMapTasks 执行完再去 fetch。因为 fetch 来的 FileSegments 要先在内存做缓冲，所以一次 fetch 的 FileSegments 总大小不能太大。Spark 规定这个缓冲界限不能超过
> 
>   spark.reducer.maxMbInFlight，这里用 softBuffer 表示，默认大小为 48MB。一个 softBuffer 里面一般包含多个 FileSegment，但如果某个 FileSegment 特别大的话，这一个就可以填满甚至超过 softBuffer 的界限。

* 边fetch边处理还是一次性fetch完再处理?
> 边 fetch 边处理。本质上，MapReduce shuffle 阶段就是边 fetch 边使用 combine() 进行处理，只是 combine() 处理的是部分数据。MapReduce 为了让进入 reduce() 的 records 有序，必须等到全部数据都 shuffle-sort 后再开始 reduce()。因为 Spark 不要求 shuffle 后的数据全局有序，因此没必要等到全部数据 shuffle 完成后再处理。那么如何实现边 shuffle 边处理，而且流入的 records 是无序的？答案是使用可以 aggregate 的数据结构，比如 HashMap。每 shuffle 得到（从缓冲的 FileSegment 中 deserialize 出来）一个.

### Spark Shuffle Fetch and Aggregator

Shuffle write写出去的数据要被Reducer使用，就需要shuffle fetcher将所需的数据fetch过来，这里的fetch包括本地和远端，因为shuffle数据有可能一部分是存储在本地的。

Spark对shuffle fetcher实现了两套不同的框架：
* NIO通过socket连接去fetch数据；
* OIO通过netty server去fetch数据。

分别对应的类是`BasicBlockFetcherIterator`和`NettyBlockFetcherIterator`。

在Spark 0.7和更早的版本中，只支持BasicBlockFetcherIterator，而BasicBlockFetcherIterator在shuffle数据量比较大的情况下performance始终不是很好，无法充分利用网络带宽，为了解决这个问题，添加了新的shuffle fetcher来试图取得更好的性能。

对于早期shuffle性能的评测可以参看Spark usergroup。当然现在BasicBlockFetcherIterator的性能也已经好了很多，使用的时候可以对这两种实现都进行测试比较。

接下来说一下aggregator。我们都知道在Hadoop MapReduce的shuffle过程中，shuffle fetch过来的数据会进行merge sort，使得相同key下的不同value按序归并到一起供Reducer使用，这个过程可以参看下图：

![Spark Shuffle Aggregator过程](http://olno3yiqc.bkt.clouddn.com/spark%20shuffle%20aggregator%E8%BF%87%E7%A8%8B.jpg)

{% em %}所有的merge sort都是在磁盘上进行的，有效地控制了内存的使用，但是代价是更多的磁盘IO。{% endem %}

** 那么Spark是否也有merge sort呢，还是以别的方式实现，下面我们就细细说明。**

首先虽然Spark属于MapReduce体系，但是对传统的MapReduce算法进行了一定的改变。{% em %}Spark假定在大多数用户的case中，shuffle数据的sort不是必须的，比如word count，强制地进行排序只会使性能变差，因此Spark并不在Reducer端做merge sort。{% endem %} 既然没有merge sort那Spark是如何进行reduce的呢？这就要说到aggregator了。

{% em %}aggregator本质上是一个hashmap，它是以map output的key为key，以任意所要combine的类型为value的hashmap。{% endem %} 当我们在做word count reduce计算count值的时候，它会将shuffle fetch到的每一个key-value pair更新或是插入到hashmap中(若在hashmap中没有查找到，则插入其中；若查找到则更新value值)。这样就不需要预先把所有的key-value进行merge sort，而是来一个处理一个，省下了外部排序这一步骤。但同时需要注意的是reducer的内存必须足以存放这个partition的所有key和count值，因此对内存有一定的要求。

在上面word count的例子中，因为value会不断地更新，而不需要将其全部记录在内存中，因此内存的使用还是比较少的。考虑一下如果是group by key这样的操作，Reducer需要得到key对应的所有value。在Hadoop MapReduce中，由于有了merge sort，因此给予Reducer的数据已经是group by key了，而Spark没有这一步，因此需要将key和对应的value全部存放在hashmap中，并将value合并成一个array。可以想象为了能够存放所有数据，用户必须确保每一个partition足够小到内存能够容纳，这对于内存是一个非常严峻的考验。因此Spark文档中建议用户涉及到这类操作的时候尽量增加partition，也就是增加Mapper和Reducer的数量。

增加Mapper和Reducer的数量固然可以减小partition的大小，使得内存可以容纳这个partition。但是我们在shuffle write中提到，bucket和对应于bucket的write handler是由Mapper和Reducer的数量决定的，task越多，bucket就会增加的更多，由此带来write handler所需的buffer也会更多。在一方面我们为了减少内存的使用采取了增加task数量的策略，另一方面task数量增多又会带来buffer开销更大的问题，因此陷入了内存使用的两难境地。

为了减少内存的使用，只能将aggregator的操作从内存移到磁盘上进行，Spark社区也意识到了Spark在处理数据规模远远大于内存大小时所带来的问题。因此PR303提供了外部排序的实现方案，相信在Spark 0.9 release的时候，这个patch应该能merge进去，到时候内存的使用量可以显著地减少。

### Spark 1.5的Tungsten-sort
Spark 1.5版本引入一种新的Shuffle方式，不过暂时只在使用Spark-SQL的时候才默认开启。现在一起来看看新的Shuffle方式tungsten-sort是怎么实现的。

要查看Shuffle的过程可以直接找到ShuffleMapTask这个类，它是Shuffle的起点。

下图是整个tungsten-sort的写入每条记录的过程:

![tungsten-sort过程](tungsten-sort过程.png)

1. Record 的 key 和 value 会以二进制的格式存储写入到 ByteArrayOutputStream 当中，用二进制的形式存储的好处是可以减少序列化和反序列化的时间。然后判断当前 Page 是否有足够的内存，如果有足够的空间就写入到当前 Page（注：Page 是一块连续的内存）。写入 Page 之后，会把内存地址 address 和 partitionId 编码成一个 8 字节的长整形记录在 InMemorySorter 当中。

2. 当前 Page 内存不够的时候会去申请新的 Page，如果内存不够就要把当前数据 Spill 到磁盘了。Shuffle 可以利用的内存默认是 Executor 内存的 0.2*0.8=0.16，它是由下面两个参数来决定的，如果数据量比较大，建议增大下面两个值，减少 Spill 的次数。

{% ace edit=false, lang='scala', theme='monokai' %}
spark.shuffle.memoryFraction 0.2
spark.shuffle.safetyFraction 0.8
{% endace %}

3. Spill 的过程，从 InMemorySorter 反编码出来内存地址，按照 partitionId 的顺序把数据从内存写入到一个文件当中，不会对同一个 partition 的数据做排序。

4. Spill 完了内存足够就申请新的 Page，内存不够就要报错了！因为内存不够就直接抛异常的做法是无法在生产环境运行。Bug 产生的原因和它为每个任务平均分配内存的机制有关系，在数据倾斜的场景很容易复现该问题，并且这个异常不应该抛，内存不足就继续 Spill。请关注下面这个 [Bug](https://issues.apache.org/jira/browse/SPARK-10474)。

实践的时候发现有两个方法可以降低它产生的几率，增加 partition 数量和减小 Page 的大小。Page 的大小通过参数 spark.buffer.pageSize 来设置，单位是 bytes，最小是 1MB，最大是 64MB。默认的计算公式是：`nextPowerOf2(maxMemory / cores / 16)` （注：maxMemory 指的是上面提到的 Shuffle 可用内存，nextPowerOf2 是 2 的次方）。

5. 所有数据写入完毕之后，会把 Spill 产生的所有文件合并成一个数据文件，并生成一个索引文件，如果 map 数是 M，那生成的文件个数就是 2M。Shuffle Writer 的工作到这里就结束了，Shuffle Reader 沿用了 Sort-based 的 Reader 来读取 Shuffle 产生的数据。合并的过程有个优化点，它会使用 NIO 的 FileChannel 去合并文件，不过使用条件比较苛刻，必须设置以下参数并且 Kernel 内核不能是 2.6.32 版本。

{% ace edit=false, lang='scala', theme='monokai' %}
spark.shuffle.compress true
spark.io.compression.codec org.apache.spark.io.LZFCompressionCodec
spark.file.transferTo true
{% endace %}

从官方的宣传来看，Spark 1.5 的性能提升是巨大的，鉴于目前 Tungsten-sort 的实现方式仍然存在问题，想要在生产环境使用 Tungsten-sort，还需要耐心等待。

参考资料:
* [董的博客](http://dongxicheng.org/framework-on-yarn/apache-spark-shuffle-details/)
* [YuMo' Blog](http://xialeizhou.com/2015/12/08/Spark-Shuffle%E8%AF%A6%E8%A7%A3/)
* [隔壁老杨hongs](http://blog.csdn.net/u014393917/article/details/25387337)
* [祝威廉对Spark Shuffle的分析](http://www.jianshu.com/p/d328c96aebfd)
* [岑玉海对Spark Shuffle的分析](https://www.ibm.com/developerworks/cn/opensource/os-cn-spark-core/)