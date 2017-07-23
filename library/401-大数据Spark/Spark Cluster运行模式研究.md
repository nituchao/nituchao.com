---
"categories": ["Spark"],
"tags": ["Spark"],
"date": "2014-06-22T13:32:00+08:00",
"title": "Spark运行模式研究"

---

Spark是一个基于内存的分布式计算系统，该系统运行稳定，设计精妙，语法简洁，是很多公司首选的大数据处理系统，深入理解它的运行逻辑、工作方式对我们进行Spark开发，错误排查，性能调优都非常有帮助。Spark本身支持local，Standalone，Cluster等多种运行模式以对应不同的部署环境。其中，local运行模式适用于开发环境进行调试，可以通过参数指定单线程或者多个线程。Standalone即独立模式，是Spark本身自带的完整服务，可单独部署到一个集群中，无需依赖其他资源管理系统（如Yarn，Mesos等），通常用在生产环境。Cluster即分布式模式，Spark能够以集群的形式运行，可用的集群管理系统有Yarn、Mesos等。集群管理的核心功能是资源管理和任务调度，通常用在生产环境。本文想重点研究一下Standalone模式和Cluster模式的运行过程。

### Spark运行模式

基本上，Spark的运行模式取决于传递给SparkContext的MASTER环境变量的值，个别模式还需要辅助的程序接口来配合使用，目前支持的Master字符串及URL包括：

| **Master URL**    | **Meaning**                              |
| ----------------- | ---------------------------------------- |
| local             | 在本地运行，只有一个工作进程，无并行计算能力。                  |
| local[K]          | 在本地运行，有K个工作进程，通常设置K为机器的CPU核心数量。          |
| local[*]          | 在本地运行，工作进程数量等于机器的CPU核心数量。                |
| spark://HOST:PORT | 以Standalone模式运行，这是Spark自身提供的集群运行模式，默认端口号: 7077。详细文档见:Spark standalone cluster。 |
| mesos://HOST:PORT | 在Mesos集群上运行，Driver进程和Worker进程运行在Mesos集群上，部署模式必须使用固定值:--deploy-mode cluster。详细文档见:MesosClusterDispatcher. |
| yarn-client       | 在Yarn集群上运行，Driver进程在本地，Work进程在Yarn集群上，部署模式必须使用固定值:--deploy-mode client。Yarn集群地址必须在HADOOP_CONF_DIRorYARN_CONF_DIR变量里定义。 |
| yarn-cluster      | 在Yarn集群上运行，Driver进程在Yarn集群上，Work进程也在Yarn集群上，部署模式必须使用固定值:--deploy-mode client。Yarn集群地址必须在HADOOP_CONF_DIRorYARN_CONF_DIR变量里定义。 |

用户在提交任务给Spark处理时，以下两个参数共同决定了Spark的运行方式。

· –master MASTER_URL ：决定了Spark任务提交给哪种集群处理。

· –deploy-mode DEPLOY_MODE：决定了Driver的运行方式，可选值为Client或者Cluster。



#### Spark运行架构的特点

每个Application获取专属的executor进程，该进程在Application期间一直驻留，并以多线程方式运行Tasks。这种Application隔离机制有其优势的，无论是从调度角度看（每个Driver调度它自己的任务），还是从运行角度看（来自不同Application的Task运行在不同的JVM中）。当然，这也意味着Spark Application不能跨应用程序共享数据，除非将数据写入到外部存储系统。

Spark与资源管理器无关，只要能够获取Executor进程，并能够保持相互通信就可以了。

提交SparkContext的Client应该靠近Worker节点（运行Executor的节点），最好是在同一个机架里，因为Spark Application运行过程中SparkContext和Executor之间有大量的信息交换；如果想在远程集群中运行，最好使用RPC将SparkContext提交给集群，不要远离Worker运行SparkContext。

#### 总结

用户将应用提交给Spark处理时，需要指定集群类型和Driver的运行方式。其中，集群类型包括本地，Spark Standalone，Mesos，Yarn等，Driver的运行方式则有Client和Cluster两种。集群类型决定了Spark使用资源的方式，Driver的运行方式则决定了Spark任务在运行期间Worker进程的跟踪，管理方式。

### Standalone运行模式

Spark Standalone模式，即独立模式，自带完整的服务，可单独部署到一个集群中，无需依赖其他资源管理系统。在该模式下，用户可以通过手动启动Master和Worker来启动一个独立的集群。其中，Master充当了资源管理的角色，Workder充当了计算节点的角色。在该模式下，Spark Driver程序在客户端(Client)运行，而Executor则在Worker节点上运行。

以下是一个运行在Standalone模式下，包含一个Master节点，两个Worker节点的Spark任务调度交互部署架构图。

![Spark Standalone模式运行调度图](http://7jpphv.com1.z0.glb.clouddn.com/spark-standalone-schedule.png)

从上面的Spark任务调度过程可以看到:

1. 整个集群分为Master节点和Worker节点，其中Driver程序运行在客户端。Master节点负责为任务分配Worker节点上的计算资源，两者会通过相互通信来同步资源状态，见途中红色双向箭头。
2. 客户端启动任务后会运行Driver程序，Driver程序中会完成SparkContext对象的初始化，并向Master进行注册。
3. 每个Workder节点上会存在一个或者多个ExecutorBackend进程。每个进程包含一个Executor对象，该对象持有一个线程池，每个线程池可以执行一个任务(task)。ExecutorBackend进程还负责跟客户端节点上的Driver程序进行通信，上报任务状态。

#### Standalone模式下任务运行过程

​	上面的过程反映了Spark在standalone模式下，整体上客户端、Master和Workder节点之间的交互。对于一个任务的具体运行过程需要更细致的分解，分解运行过程见图中的小字。

1. 用户通过bin/spark-submit部署工具或者bin/spark-class启动应用程序的Driver进程，Driver进程会初始化SparkContext对象，并向Master节点进行注册。

	2.	Master节点接受Driver程序的注册，检查它所管理的Worker节点，为该Driver程序分配需要的计算资源Executor。Worker节点完成Executor的分配后，向Master报告Executor的状态。


	3.	Worker节点上的ExecutorBackend进程启动后，向Driver进程注册。

4. Driver进程内部通过DAG Schaduler，Stage Schaduler，Task Schaduler等过程完成任务的划分后，向Worker节点上的ExecutorBackend分配TASK。

	5.	ExecutorBackend进行TASK计算，并向Driver报告TASK状态，直至结束。


	6.	Driver进程在所有TASK都处理完成后，向Master注销。

#### 总结

Spark能够以standalone模式运行，这是Spark自身提供的运行模式，用户可以通过手动启动master和worker进程来启动一个独立的集群，也可以在一台机器上运行这些守护进程进行测试。standalone模式可以用在生产环境，它有效的降低了用户学习、测试Spark框架的成本。

standalone模式目前只支持跨应用程序的简单FIFO调度。然而，为了允许多个并发用户，你可以控制每个应用使用的资源的最大数。默认情况下，它会请求使用集群的全部CUP内核。

缺省情况下，standalone任务调度允许worker的失败（在这种情况下它可以将失败的任务转移给其他的worker）。但是，调度器使用master来做调度，这会产生一个单点问题：如果master崩溃，新的应用不会被创建。为了解决这个问题，可以zookeeper的选举机制在集群中启动多个master，也可以使用本地文件实现单节点恢复。



### Cluster运行模式

Spark能够以集群的形式运行，可用的集群管理系统有Yarn，Mesos等。集群管理器的核心功能是资源管理和任务调度。以Yarn为例，Yarn以Master/Slave模式工作，在Master节点运行的是Resource Manager(RM)，负责管理整个集群的资源和资源分配。在Slave节点运行的Node Manager(NM)，是集群中实际拥有资源的工作节点。我们提交Job以后，会将组成Job的多个Task调度到对应的Node Manager上进行执行。另外，在Node  Manager上将资源以Container的形式进行抽象，Container包括两种资源内存和CPU。

以下是一个运行在Yarn集群上，包含一个Resource Manager节点，三个Node Manager节点(其中，两个是Worker节点，一个Master节点)的Spark任务调度交换部署架构图。

![Spark Cluster运行模式调度图](http://7jpphv.com1.z0.glb.clouddn.com/spark-cluster-schedule.png)

从上面的Spark任务调度过程图可以看到:

1. 整个集群分为Master节点和Worker节点，它们都存在于Node Manager节点上，在客户端提交任务时由Resource Manager统一分配，运行Driver程序的节点被称为Master节点，执行具体任务的节点被称为Worder节点。Node Manager节点上资源的变化都需要及时更新给Resource Manager，见图中红色双向箭头。
2. Master节点上常驻Master守护进程 —— Driver程序，Driver程序中会创建SparkContext对象，并负责跟各个Worker节点上的ExecutorBackend进程进行通信，管理Worker节点上的任务，同步任务进度。实际上，在Yarn中Node Manager之间的关系是平等的，因此Driver程序会被调度到任何一个Node Manager节点。
3. 每个Worker节点上会存在一个或者多个ExecutorBackend进程。每个进程包含一个Executor对象，该对象持有一个线程池，每个线程池可以执行一个任务(task)。ExecutorBackend进程还负责跟Master节点上的Driver程序进行通信，上报任务状态。

#### 集群下任务运行过程

上面的过程反映出了Spark在集群模式下，整体上Resource Manager和Node Manager节点间的交互，Master和Worker之间的交互。对于一个任务的具体运行过程需要更细致的分解，分解运行过程见图中的小字。

1. 用户通过bin/spark-submit部署工具或者bin/spark-class向Yarn集群提交应用程序。
2. Yarn集群的Resource Manager为提交的应用程序选择一个Node Manager节点并分配第一个container，并在该节点的container上启动SparkContext对象。
3. SparkContext对象向Yarn集群的Resource Manager申请资源以运行Executor。
4. Yarn集群的Resource Manager分配container给SparkContext对象，SparkContext和相关的Node Manager通讯，在获得的container上启动ExecutorBackend守护进程，ExecutorBackend启动后开始向SparkContext注册并申请Task。
5. SparkContext分配Task给ExecutorBackend执行。
6. ExecutorBackend开始执行Task，并及时向SparkContext汇报运行状况。
7. Task运行完毕，SparkContext归还资源给Node Manager，并注销退。

#### 总结

Spark能够以集群的方式运行，这里的可选集群有Yarn和Mesos。在集群模式下，Spark的Driver程序可能被调度到任何一个节点，任务执行完成后，集群分配的资源将被回收。



### 参考资料

http://dongxicheng.org/framework-on-yarn/apache-spark-comparing-three-deploying-ways/
http://colobu.com/2014/12/09/spark-standalone-mode/
https://spark.apache.org/docs/latest/spark-standalone.html
http://spark-internals.books.yourtion.com/markdown/1-Overview.html