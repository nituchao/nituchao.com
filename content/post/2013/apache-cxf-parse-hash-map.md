---
title: "Apache CXF解析Map/HashMap"
date: "2013-12-11T14:06:00+08:00"
categories: ["Java"]
tags: ["CXF","Web Service"]
draft: false

---

项目中WebService框架用的是Apache CXF，但是在使用中发现Apache CXF不支持解析Map和HashMap，而且SOAP报文(XML)和JavaBean的转化是通过JAXB实现的，没办法，自己写了个Map到XML的适配器，来实现两者的转化。


## Map适配器
MapAdapter用来完成Java的Map类型与XML中对应节点的转换。

以MapAdatper为中心，一边是XML类型的SOAP报文，一边是以HashMap为元素的list列表。通过以下两个方法完成双向转换:

* unmarshal: 完成XML到JAVA的转换。
* marshal: 完成JAVA到XML的转换。

该适配器会通过注解在具体的实体类上指定。

```
import java.util.HashMap;
import java.util.Map;


import javax.xml.bind.annotation.adapters.XmlAdapter;


/**
 * Map适配器，完成Java中map与XML中对应节点的转换
 * 
 * <p>
 * detailed comment
 * @author zWX184091 2013-8-15
 * @see
 * @since 1.0
 */
public class MapAdapter extends XmlAdapter<MapConvertor, HashMap<String, String>>
{


    /**
     * XML to JAVA
     * 
     * @param map
     * @return HashMap<String, String>
     * @throws Exception
     */
    @Override
    public HashMap<String, String> unmarshal(MapConvertor map) throws Exception
    {
        // TODO Auto-generated method stub
        HashMap<String, String> result = new HashMap<String, String>();

        // 遍历MapConvertor，将XML节点内容写入JavaBean Map对象
        for (MapConvertor.MapEntry e : map.getEntry())
        {
            result.put(e.getKey(), e.getValue());
        }
        return result;
    }


    /**
     * JAVA to XML
     * 
     * @param map
     * @return MapConvertor
     * @throws Exception
     */
    @Override
    public MapConvertor marshal(HashMap<String, String> map) throws Exception
    {


        // 创建MapConvertor对象，盛放XML节点内容
        MapConvertor convertor = new MapConvertor();


        // 遍历map，将JavaBean中数据写入XML节点
        for (Map.Entry<String, String> entry : map.entrySet())
        {
            // 创建空的MapEntry对象(该mapEntry应该放在循环内，防止重复使用同一个java对象引用)
            MapConvertor.MapEntry mapEntry = new MapConvertor.MapEntry();


            mapEntry.setKey(entry.getKey());
            mapEntry.setValue(entry.getValue());


            convertor.addEntry(mapEntry);
        }
        return convertor;
    }
}
```

## Map转换器
Map转换器中聚合了一个元素为MapEntry的list集合对象，MapEntry中聚合了一个String类型的key成员和一个String类型的value成员，用来完成和Java中的HashMap的对接。

```
import java.util.ArrayList;
import java.util.List;
import java.util.Map.Entry;


import javax.xml.bind.annotation.XmlAccessType;
import javax.xml.bind.annotation.XmlAccessorType;
import javax.xml.bind.annotation.XmlType;


/**
 * Map转换器
 * 
 * <p>
 * detailed comment
 * @author zWX184091 2013-7-31
 * @see
 * @since 1.0
 */
@XmlType(name = "MapConvertor")
@XmlAccessorType(XmlAccessType.FIELD)
public class MapConvertor
{


    // SOAP报文结构是一个Map的List
    private List<MapEntry> entry = new ArrayList<MapEntry>();


    public void addEntry(MapEntry entry)
    {
        this.entry.add(entry);
    }


    public List<MapEntry> getEntry()
    {
        return entry;
    }


    public void setEntry(List<MapEntry> entry)
    {
        this.entry = entry;
    }


    public static class MapEntry
    {
        private String key;


        private String value;


        public MapEntry()
        {
            super();
        }


        public MapEntry(String key, String value)
        {
            super();
            this.key = key;
            this.value = value;
        }


        public MapEntry(Entry<String, String> entry)
        {
            super();
            this.key = entry.getKey();
            this.value = entry.getValue();
        }


        public String getKey()
        {
            return key;
        }


        public String getValue()
        {
            return value;
        }


        public void setKey(String key)
        {
            this.key = key;
        }


        public void setValue(String value)
        {
            this.value = value;
        }
    }
}
```

## 实体类
SigParam是一个Java的实体类，该类的成员变量是一个以HashMap为元素的List列表。在get方法上通过注解@XmlJavaTypeAdapter来指定解析类。

```
public class SigParam
{
    // SOAP报文结构是一个Map的集合(List)
    private List<HashMap<String, String>> entry;


    public SigParam(List<HashMap<String, String>> entry)
    {
        super();
        this.entry = entry;
    }


    public SigParam()
    {
        super();
    }


    @XmlElement(name = "string2stringMap")
    @XmlJavaTypeAdapter(MapAdapter.class)
    public List<HashMap<String, String>> getEntry()
    {
        return entry;
    }


    public void setEntry(List<HashMap<String, String>> entry)
    {
        this.entry = entry;
    }
}

```

## SOAP报文内容

```
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
                  xmlns:ser="http://service.ws.userinterface.sa.security.com/">
   <soapenv:Header>
      <userId>WHITE_GROUP_ADD_001</userId>
      <password>000</password>
   </soapenv:Header>
   <soapenv:Body>
      <ser:execute>
         <arg0>
            <records>
               <string2stringMap>
                  <entry>
                     <key>groupName</key>
                     <value>Hello_ggood</value>
                  </entry>
                  <entry>
                     <key>adName</key>
                     <value>最后一次测试</value>
                  </entry>
                  <entry>
                     <key>time</key>
                     <value>0909</value>
                  </entry>
               </string2stringMap>
            </records>
            <taskCode>WHITE_GROUP_ADD_001</taskCode>
         </arg0>
      </ser:execute>
   </soapenv:Body>
</soapenv:Envelope>
```

## 总结
原生的JAXB支持简单的XML结构到JAVA实体类的解析。通过上面的Map适配器MapAdapter可以完成XML类型中比较复杂的数据结构的解析，比如：HashMap。
