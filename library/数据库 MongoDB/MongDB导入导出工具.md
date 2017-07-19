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
[root@mongo tmp]# mongoimport --host 10.136.33.51 --port 30000 -d miui_flow_statis -c src_pv_uv /tmp/src_pv_uv
2017-07-19T11:56:44.147+0800	connected to: 10.136.33.51:30000
2017-07-19T11:56:44.955+0800	imported 12740 documents
```

