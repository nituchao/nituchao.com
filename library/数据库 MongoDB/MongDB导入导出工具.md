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
[root@mongo01 tmp]# mongoexport --host 10.136.33.51 --port 30000 -d miui_flow_statis -c src_pv_uv -o /tmp/src_pv_uv
2017-07-19T11:47:27.940+0800	connected to: 10.136.33.51:30000
2017-07-19T11:47:28.323+0800	exported 12740 records
```

### MongoDB导入操作

MongoDB中的mongoimport工具可以把一个特定文件中的内容导入到指定的collection中。该工具可以导入JSON格式数据，也可以导入CSV格式数据。

通过下面的代码，将/tmp/src_pv_uv文件导入到miui_flow_statis库中的src_pv_uv集合。在/tmp/src_pv_uv文件中，每行一个JSON。

```shell
[root@mongo01 tmp]# mongoimport --host 10.136.33.51 --port 30000 -d miui_flow_statis -c src_pv_uv /tmp/src_pv_uv
2017-07-19T11:56:44.147+0800	connected to: 10.136.33.51:30000
2017-07-19T11:56:44.955+0800	imported 12740 documents
```



### MongoDB导出工具

mongoexport是Linux下的命令行工具，查看该命令的帮助文档可以看到有很多选项，我们重点分析一些常用的选项。

1, 指定主机和端口

指定MongoDB服务器IP地址。

```shell
-h, --host=<homename>
(setname/host1,host2 for replica sets)
```

指定MongoDB服务器端口号。

```shell
--port=<port>
```

通常，在导出时指定服务器主机和端口号有以下几种用法

```
# mongoexport -h host1:port
# mongoexport --host host1 --port 30000
# mongoexport --host host1:port
```



```shell
[root@c3-miui-sec-elk01 tmp]# mongoexport --help
Usage:
  mongoexport <options>

Export data from MongoDB in CSV or JSON format.

See http://docs.mongodb.org/manual/reference/program/mongoexport/ for more information.

general options:
      --help                                      print usage
      --version                                   print the tool version and exit

verbosity options:
  -v, --verbose=<level>                           more detailed log output (include multiple times for more verbosity, e.g. -vvvvv, or specify a numeric value, e.g. --verbose=N)
      --quiet                                     hide all log output

connection options:
  -h, --host=<hostname>                           mongodb host to connect to (setname/host1,host2 for replica sets)
      --port=<port>                               server port (can also use --host hostname:port)

ssl options:
      --ssl                                       connect to a mongod or mongos that has ssl enabled
      --sslCAFile=<filename>                      the .pem file containing the root certificate chain from the certificate authority
      --sslPEMKeyFile=<filename>                  the .pem file containing the certificate and key
      --sslPEMKeyPassword=<password>              the password to decrypt the sslPEMKeyFile, if necessary
      --sslCRLFile=<filename>                     the .pem file containing the certificate revocation list
      --sslAllowInvalidCertificates               bypass the validation for server certificates
      --sslAllowInvalidHostnames                  bypass the validation for server name
      --sslFIPSMode                               use FIPS mode of the installed openssl library

authentication options:
  -u, --username=<username>                       username for authentication
  -p, --password=<password>                       password for authentication
      --authenticationDatabase=<database-name>    database that holds the user's credentials
      --authenticationMechanism=<mechanism>       authentication mechanism to use

namespace options:
  -d, --db=<database-name>                        database to use
  -c, --collection=<collection-name>              collection to use

output options:
  -f, --fields=<field>[,<field>]*                 comma separated list of field names (required for exporting CSV) e.g. -f "name,age"
      --fieldFile=<filename>                      file with field names - 1 per line
      --type=<type>                               the output format, either json or csv (defaults to 'json') (default: json)
  -o, --out=<filename>                            output file; if not specified, stdout is used
      --jsonArray                                 output to a JSON array rather than one object per line
      --pretty                                    output JSON formatted to be human-readable
      --noHeaderLine                              export CSV data without a list of field names at the first line

querying options:
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

