---
title: "服务器端与客户端加密通信设计"
date: "2014-07-12T19:19:00+08:00"
categories: ["JAVA"]
tags: ["RSA", "Android"]
draft: false
---

最近的一个项目涉及到服务器与Android客户端交换一些敏感数据，这部分数据必须要经过安全加密后才能在Android与服务器间传递，然后再解密后进行相关的业务操作，而且要做到，即使客户端被恶意反编译，已经发送的数据也不会被破解。

我们首先想到的是对称加密算法`AES`和`DES`,但是，如果客户端被恶意反编译，客户端写死的密钥就会被拿到，已经发送的数据就很容易被破解了，因此，安全上，对称加密不满足我们的需求。

我们很快想到了非对称加密算法`RSA`，即使黑客拿到了客户端的公钥，没有私钥还是无法破解已经发送的数据包，但是，`RSA`算法速度非常慢，而且一次最多加密128位的数据，虽然安全上满足需求，速度和操作复杂度上还是存在一些硬伤。

于是，我们的解决办法是联合使用`RSA`和`AES`算法，具体的做法是，客户端提交的正文内容使用`AES`加密，`AES`加密时的密钥由客户端随机生成，然后把随机生成的密钥使用`RSA`算法加密后与正文内容加密后的密文一起提交给服务器端，服务器端先用自己的`RSA`私钥解密`AES`算法的密钥，然后用`AES`算法配合解密出的密钥解密正文内容。

<img src="http://olno3yiqc.bkt.clouddn.com/blog/img/RSA_1934751b.jpg" width=800px height=600px alt="RSA" />


## 交互过程

客户端提交内容如下:
```

{
    msgkey: "f7l1mKVA3TVUf9F/lUIM30bzHG+PxXEOoO3vZ0N8ulsyPu8IaO/wmKAlOqUyIHwLtQnCOU2", 
    msgtxt: "MuoJ+HrOJzneiFwvBcOV8loBhRS0LjbmRyWkvSs0C2w="
}

```
其中：

* msgtxt是客户端提交的正文内容经过`AES`算法加密后的密文，`AES`加密时的密钥key由客户端随机生成。
* msgkey是`AES`算法加密时用到的密钥key经过客户端`RSA`算法加密后的密文，`RSA`加密时的公钥由服务器端提供并固定内置的客户端。

以下是交互图:

<img src="http://olno3yiqc.bkt.clouddn.com/blog/img/rsa-aes.jpg" width=800 height=600 alt="rsa-aes" />


## RSA工具类

以下是我们用到的RSA加密/解密算法，该算法服务器端和客户端必须同时使用:

```
package com.xiaomi.miui.sec.common;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.math.BigInteger;
import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.NoSuchAlgorithmException;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;
import java.security.spec.RSAPrivateKeySpec;
import java.security.spec.RSAPublicKeySpec;
import java.util.HashMap;

import javax.crypto.Cipher;

/**
 * RSA工具类
 * Created by liang on 7/9/14.
 */

public class RSAUtils {

    /**
     * 生成公钥和私钥
     *
     * @throws NoSuchAlgorithmException
     */
    public static HashMap<String, Object> getKeys() throws NoSuchAlgorithmException {
        HashMap<String, Object> map = new HashMap<String, Object>();
        KeyPairGenerator keyPairGen = KeyPairGenerator.getInstance("RSA");
        keyPairGen.initialize(1024);
        KeyPair keyPair = keyPairGen.generateKeyPair();
        RSAPublicKey publicKey = (RSAPublicKey) keyPair.getPublic();
        RSAPrivateKey privateKey = (RSAPrivateKey) keyPair.getPrivate();
        map.put("public", publicKey);
        map.put("private", privateKey);
        return map;
    }

    /**
     * 使用模和指数生成RSA公钥
     * 注意：【此代码用了默认补位方式，为RSA/None/PKCS1Padding，不同JDK默认的补位方式可能不同，如Android默认是RSA/None/NoPadding】
     *
     * @param modulus  模
     * @param exponent 指数
     * @return
     */
    public static RSAPublicKey getPublicKey(String modulus, String exponent) {
        try {
            BigInteger b1 = new BigInteger(modulus);
            BigInteger b2 = new BigInteger(exponent);
            KeyFactory keyFactory = KeyFactory.getInstance("RSA");
            RSAPublicKeySpec keySpec = new RSAPublicKeySpec(b1, b2);
            return (RSAPublicKey) keyFactory.generatePublic(keySpec);
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    /**
     * 使用模和指数生成RSA私钥
     * 注意：【此代码用了默认补位方式，为RSA/None/PKCS1Padding，不同JDK默认的补位方式可能不同，如Android默认是RSA/None/NoPadding】
     *
     * @param modulus  模
     * @param exponent 指数
     * @return
     */
    public static RSAPrivateKey getPrivateKey(String modulus, String exponent) {
        try {
            BigInteger b1 = new BigInteger(modulus);
            BigInteger b2 = new BigInteger(exponent);
            KeyFactory keyFactory = KeyFactory.getInstance("RSA");
            RSAPrivateKeySpec keySpec = new RSAPrivateKeySpec(b1, b2);
            return (RSAPrivateKey) keyFactory.generatePrivate(keySpec);
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    /**
     * 公钥加密
     *
     * @param data
     * @param publicKey
     * @return
     * @throws Exception
     */
    public static String encryptByPublicKey(String data, RSAPublicKey publicKey) throws Exception {
        Cipher cipher = Cipher.getInstance("RSA/ECB/PKCS1Padding");
        cipher.init(Cipher.ENCRYPT_MODE, publicKey);
        // 模长
        int key_len = publicKey.getModulus().bitLength() / 8;
        // 加密数据长度 <= 模长-11
        String[] datas = splitString(data, key_len - 11);
        String mi = "";
        //如果明文长度大于模长-11则要分组加密
        for (String s : datas) {
            mi += bcd2Str(cipher.doFinal(s.getBytes()));
        }
        return mi;
    }

    /**
     * 私钥解密
     *
     * @param data
     * @param privateKey
     * @return
     * @throws Exception
     */
    public static String decryptByPrivateKey(String data, RSAPrivateKey privateKey) throws Exception {
        Cipher cipher = Cipher.getInstance("RSA/ECB/PKCS1Padding");
        cipher.init(Cipher.DECRYPT_MODE, privateKey);
        //模长
        int key_len = privateKey.getModulus().bitLength() / 8;
        byte[] bytes = data.getBytes();
        byte[] bcd = ASCII_To_BCD(bytes, bytes.length);
        System.err.println(bcd.length);
        //如果密文长度大于模长则要分组解密
        String ming = "";
        byte[][] arrays = splitArray(bcd, key_len);
        for (byte[] arr : arrays) {
            ming += new String(cipher.doFinal(arr));
        }
        return ming;
    }

    /**
     * ASCII码转BCD码
     */
    public static byte[] ASCII_To_BCD(byte[] ascii, int asc_len) {
        byte[] bcd = new byte[asc_len / 2];
        int j = 0;
        for (int i = 0; i < (asc_len + 1) / 2; i++) {
            bcd[i] = asc_to_bcd(ascii[j++]);
            bcd[i] = (byte) (((j >= asc_len) ? 0x00 : asc_to_bcd(ascii[j++])) + (bcd[i] << 4));
        }
        return bcd;
    }

    public static byte asc_to_bcd(byte asc) {
        byte bcd;

        if ((asc >= '0') && (asc <= '9'))
            bcd = (byte) (asc - '0');
        else if ((asc >= 'A') && (asc <= 'F'))
            bcd = (byte) (asc - 'A' + 10);
        else if ((asc >= 'a') && (asc <= 'f'))
            bcd = (byte) (asc - 'a' + 10);
        else
            bcd = (byte) (asc - 48);
        return bcd;
    }

    /**
     * BCD转字符串
     */
    public static String bcd2Str(byte[] bytes) {
        char temp[] = new char[bytes.length * 2], val;

        for (int i = 0; i < bytes.length; i++) {
            val = (char) (((bytes[i] & 0xf0) >> 4) & 0x0f);
            temp[i * 2] = (char) (val > 9 ? val + 'A' - 10 : val + '0');

            val = (char) (bytes[i] & 0x0f);
            temp[i * 2 + 1] = (char) (val > 9 ? val + 'A' - 10 : val + '0');
        }
        return new String(temp);
    }

    /**
     * 拆分字符串
     */
    public static String[] splitString(String string, int len) {
        int x = string.length() / len;
        int y = string.length() % len;
        int z = 0;
        if (y != 0) {
            z = 1;
        }
        String[] strings = new String[x + z];
        String str = "";
        for (int i = 0; i < x + z; i++) {
            if (i == x + z - 1 && y != 0) {
                str = string.substring(i * len, i * len + y);
            } else {
                str = string.substring(i * len, i * len + len);
            }
            strings[i] = str;
        }
        return strings;
    }

    /**
     * 拆分数组
     */
    public static byte[][] splitArray(byte[] data, int len) {
        int x = data.length / len;
        int y = data.length % len;
        int z = 0;
        if (y != 0) {
            z = 1;
        }
        byte[][] arrays = new byte[x + z][];
        byte[] arr;
        for (int i = 0; i < x + z; i++) {
            arr = new byte[len];
            if (i == x + z - 1 && y != 0) {
                System.arraycopy(data, i * len, arr, 0, y);
            } else {
                System.arraycopy(data, i * len, arr, 0, len);
            }
            arrays[i] = arr;
        }
        return arrays;
    }

	/**
	* 测试
	*/
    public static void main(String[] args) throws Exception {
        // TODO Auto-generated method stub
        HashMap<String, Object> map = RSAUtils.getKeys();
        //生成公钥和私钥
        RSAPublicKey publicKey = (RSAPublicKey) map.get("public");
        RSAPrivateKey privateKey = (RSAPrivateKey) map.get("private");

        //模
        String modulus = publicKey.getModulus().toString();
        //公钥指数
        String public_exponent = publicKey.getPublicExponent().toString();
        //私钥指数
        String private_exponent = privateKey.getPrivateExponent().toString();
        //明文
        String ming = "XiaomiPostSmsPublicKey";

        //使用模和指数生成公钥和私钥
        RSAPublicKey pubKey = RSAUtils.getPublicKey(modulus, public_exponent);
        RSAPrivateKey priKey = RSAUtils.getPrivateKey(modulus, private_exponent);

        RSAPublicKey tmpPubKey = null;
        RSAPrivateKey tmpPriKey = null;

		// 将成对的公钥和私钥序列化到文件，这样就可以内置到客户端和服务器端了
        try{
            ObjectOutputStream publicKeyOutput = new ObjectOutputStream(new FileOutputStream("/home/work/rsapubkey"));
            publicKeyOutput.writeObject(pubKey);

            ObjectOutputStream privateKeyOutput = new ObjectOutputStream(new FileOutputStream("/home/work/rsaprikey"));
            privateKeyOutput.writeObject(priKey);

            ObjectInputStream publicKeyInput = new ObjectInputStream(new FileInputStream("/home/work/rsapubkey"));
            tmpPubKey = (RSAPublicKey) publicKeyInput.readObject();

            ObjectInputStream privateKeyInput = new ObjectInputStream(new FileInputStream("/home/work/rsaprikey"));
            tmpPriKey = (RSAPrivateKey) privateKeyInput.readObject();
        }catch(Exception e){
            e.printStackTrace();
        }

        //加密后的密文
        String mi = RSAUtils.encryptByPublicKey(ming, tmpPubKey);
        System.err.println(mi);
        //解密后的明文
        ming = RSAUtils.decryptByPrivateKey(mi, tmpPriKey);
        System.err.println(ming);
    }
}
```

## 需要特别注意的地方
由于Java JDK和Android JDK在实例化`Cipher`对象时使用不同的算法，比如:
```
Java:
Cipher cipher = Cipher.getInstance("RSA/ECB/PKCS1Padding");

Android:
Cipher cipher = Cipher.getInstance("RSA/ECB/NoPadding");
```
因此，如果使用默认算法的话，会出现Android客户端加密数据无法在服务器端解密的错误，比如：
```
javax.crypto.BadPaddingException: Decryption error
    at sun.security.rsa.RSAPadding.unpadV15(RSAPadding.java:311)
    at sun.security.rsa.RSAPadding.unpad(RSAPadding.java:255)
    at com.sun.crypto.provider.RSACipher.a(DashoA13*..)
    at com.sun.crypto.provider.RSACipher.engineDoFinal(DashoA13*..)
    at javax.crypto.Cipher.doFinal(DashoA13*..)
```
所以，上文中给出的`RSAUtils.java`中无论是加密方法还是解密方法，我都使用的是一样的算法(**RSA/ECB/PKCS1Padding**)，而不是默认的算法(**RSA**)，这样就可以完美解决问题了。


