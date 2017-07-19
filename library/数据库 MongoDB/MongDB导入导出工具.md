---
"categories": ["MongoDB"],
"tags": ["MongoDB"],
"date": "2014-06-22T13:32:00+08:00",
"title": "MongoDB导入导出工具"

---

### MongoDB导出操作

MongoDB中的mongoexport工具可以把一个collection导出成JSON格式或者CSV格式的文件，速度非常快。

通过下面的代码，将miui_flow_statis库中的src_pv_uv集合导出到文本文件，在导出的文件中，每行一个JSON，代表一个Document。

```shell
# mongoexport --host 10.136.33.51 --port 30000 -d miui_flow_statis -c src_pv_uv -o /tmp/src_pv_uv
2017-07-19T11:47:27.940+0800	connected to: 10.136.33.51:30000
2017-07-19T11:47:28.323+0800	exported 12740 records
```

### MongoDB导入操作

MongoDB中的mongoimport工具可以把一个特定文件中的内容导入到指定的collection中。该工具可以导入JSON格式数据，也可以导入CSV格式数据。

通过下面的代码，将/tmp/src_pv_uv文件导入到miui_flow_statis库中的src_pv_uv集合。在/tmp/src_pv_uv文件中，每行一个JSON。

```shell
# mongoimport --host 10.136.33.51 --port 30000 -d miui_flow_statis -c src_pv_uv /tmp/src_pv_uv
2017-07-19T11:56:44.147+0800	connected to: 10.136.33.51:30000
2017-07-19T11:56:44.955+0800	imported 12740 documents
```



### MongoDB导出工具

mongoexport是Linux下的命令行工具，查看该命令的帮助文档可以看到有很多选项，我们重点分析一些常用的选项。

#### 1, 指定主机和端口

指定MongoDB服务器IP地址。

```shell
-h, --host=<homename>
(setname/host1,host2 for replica sets)
```

指定MongoDB服务器端口号（注意：-p是密码）。

```shell
--port=<port>
```

通常，在导出时指定服务器主机和端口号有以下几种用法

```shell
# mongoexport -h host1:port
# mongoexport --host host1 --port 30000
# mongoexport --host replicaSetName/host1,host2 --port 3000
```



#### 2, 指定用户名和密码

当MongoDB设置了账号认证时，需要在导出的时候提供用户名和密码。

```shell
-u, --username=<username>                       username for authentication
-p, --password=<password>                       password for authentication
```



#### 3, 指定数据库和集合名称

在使用mongoexport导出时，需要指定MongoDB的数据库名称和集合名称，可以通过下面两个选项设置。

```shell
-d, --db=<database-name>                        database to use
-c, --collection=<collection-name>              collection to use
```



#### 4, 指定输出文件

在使用mongoexport导出时，可以选择输出文件的类型(json、csv或控制台)。当选择输出为json类型文件时，可以设置输出每行一个json对象或一个json对象的数组，还可以对输出json进行格式化(pretty)。当选择输出为csv时，可以选择要输出的表头域，也可以省略表头域。默认输出的是json，每行一个json对象。当没有指定`-o`选项时，会将导出内容打印在控制台上。

```shell
-f, --fields=<field>[,<field>]*					  csv header fields, eg: -f "name,age"
    --fieldFile=<filename>                        file with field names - 1 per line
    --type=<type>								  'json' or 'csv', default 'json'
-o, --out=<filename>                              output file; if not specified, stdout is used
      --jsonArray                                 output to a JSON array rather than one object per line
      --pretty                                    output JSON formatted to be human-readable
      --noHeaderLine                              export CSV data without a list of field names at the first line
```

通常，在导出时可以有以下组合来指定导出文件的格式和内容。

导出为文件，格式为json，每行一个json对象。

```shell
-o /tmp/data.txt
```

导出为文件，格式为json，构成一个json数组。

```shell
-o /tmp/data.txt --jsonArray
```

导出为文件，格式为json，构成一个json数组，并进行格式化。

```shell
-o /tmp/data.txt --jsonArray --pretty
```

导出为文件，格式为csv，指定表头域。

```shell
-f "name,age"
```



#### 5, 查询条件

在使用mongoexport导出数据时，可以指定查询语句或者指定一个包含查询语句的文件，为导出添加条件。

```shell
-q, --query=<json>                              query filter, as a JSON string, e.g., '{x:{$gt:1}}'
    --queryFile=<filename>                      path to a file containing a query filter (JSON)
-k, --slaveOk                                   allow secondary reads if available (default true) (default: false)
      --readPreference=<string>|<json>            specify either a preference name or a preference json object
      --forceTableScan                            force a table scan (do not use $snapshot)
      --skip=<count>                              number of documents to skip
      --limit=<count>                             limit the number of documents to export
      --sort=<json>                               sort order, as a JSON string, e.g. '{x:1}'
      --assertExists                              if specified, export fails if the collection does not exist (default: false)
```



### MongoDB导入工具

mongoimport是Linux下的命令行工具，查看该命令的帮助文档可以看到有很多选项，我们重点分析一些常用的选项。

#### 1, 指定主机和端口

指定MongoDB服务器IP地址。

```shell
-h, --host=<homename>
(setname/host1,host2 for replica sets)
```

指定MongoDB服务器端口号（注意：-p是密码）。

```shell
--port=<port>
```

通常，在导出时指定服务器主机和端口号有以下几种用法

```shell
# mongoimport -h host1:port
# mongoimport --host host1 --port 30000
# mongoimport --host replicaSetName/host1,host2 --port 3000
```



#### 2, 指定用户名和密码

当MongoDB设置了账号认证时，需要在导出的时候提供用户名和密码。

```shell
-u, --username=<username>                       username for authentication
-p, --password=<password>                       password for authentication
```



#### 3, 指定数据库和集合名称

在使用mongoimport导出时，需要指定MongoDB的数据库名称和集合名称，可以通过下面两个选项设置。

```shell
-d, --db=<database-name>                        database to use
-c, --collection=<collection-name>              collection to use
```



#### 4, 指定输入文件

