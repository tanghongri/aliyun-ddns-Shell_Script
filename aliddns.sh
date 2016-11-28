#!/bin/sh

##########################################################################################
##################需配置信息################################################################
#主机名数组
RRs=("home @ www")
#阿里云域名
DomainName="必须设置.win"
#Access Key Id
AccessKeyId="必须设置"
#Access Key Secret
AccessKeySecret="必须设置"

##########################################################################################

#当前版本
ApiVer="2015-01-09"
#当前IP
CurrentIp=""
#保存IP
PreIp=""
#DNS IP
DnsIp=""
#当前时间
timestamp=""
#curl返回数据
curldata=""

#直接从阿里DNS服务器获取域名对应的IP信息
#dns服务器地址
#AliddnsServer="223.5.5.5"
#CurrentIp=`nslookup $RR.$DomainName $AliddnsServer 2>&1`
#PreIp=`echo "$current_ip" | grep 'Address' | tail -n1 | awk '{print $NF}'`


#对每个请求参数的名称和值进行编码。名称和值要使用UTF-8字符集进行URL编码，URL编码的编码规则是：
#i. 对于字符 A-Z、a-z、0-9以及字符“-”、“_”、“.”、“~”不编码；
#ii. 对于其他字符编码成“%XY”的格式，其中XY是字符对应ASCII码的16进制表示。比如英文的双引号（”）对应的编码就是%22
#iii. 对于扩展的UTF-8字符，编码成“%XY%ZA…”的格式；
#iv. 需要说明的是英文空格（ ）要被编码是%20，而不是加号（+）。
urlencode() {
    # urlencode <string>
    out=""
    while read -n1 c
    do
        case $c in
            [A-Za-z0-9-_、.~]) out="$out$c" ;;
            *) out="$out`printf '%%%02X' "'$c"`" ;;
        esac
    done
    echo -n $out
}

enc() {
    echo -n "$1" | urlencode
}


#执行阿里云API接口使用构造的规范化字符串按照下面的规则构造用于计算签名的字符串：
#StringToSign= HTTPMethod + “&” + percentEncode(“/”) + ”&” + percentEncode(CanonicalizedQueryString) 
#按照RFC2104的定义，使用上面的用于签名的字符串计算签名HMAC值。注意：计算签名时使用的Key就是用户持有的Access Key Secret并加上一个“&”字符(ASCII:38)，使用的哈希算法是SHA1。
#按照Base64编码规则把上面的HMAC值编码成字符串，即得到签名值（Signature）。
#将得到的签名值作为Signature参数添加到请求参数中，即完成对请求签名的过程。
#注意：得到的签名值在作为最后的请求参数值提交给DNS服务器的时候，要和其他参数一样，按照RFC3986的规则进行URL编码）。

#Get请求
GetRequest() {  
    local hash=$(echo -n "GET&%2F&`enc "$1"`" | openssl dgst -sha1 -hmac "$AccessKeySecret&" -binary | openssl base64)
    echo -n $(curl -s "http://alidns.aliyuncs.com/?$1&Signature=`enc "$hash"`")
}



#按照参数名称的字典顺序对请求中所有的请求参数（包括文档中描述的“公共请求参数”和给定了的请求接口的自定义参数，但不能包括“公共请求参数”中提到Signature参数本身）进行排序。
#注意：此排序严格大小写敏感排序。
#注：当使用GET方法提交请求时，这些参数就是请求URI中的参数部分（即URI中“?”之后由“&”连接的部分）。
#date +%s%N #生成19位数字

#获取域名记录信息
#$1 主机名称

GetRecords() {
    GetRequest "AccessKeyId=`enc "$AccessKeyId"`&Action=DescribeDomainRecords&DomainName=`enc "$DomainName"`&Format=JSON&RRKeyWord=`enc "$1"`&RegionId=cn-hangzhou&SignatureMethod=HMAC-SHA1&SignatureNonce=`date +%s%N`&SignatureVersion=1.0&Timestamp=`enc "$timestamp"`&TypeKeyWord=A&Version=2015-01-09"
}

#更新域名记录信息
#$1 主机名称
#$2 RecordId
#$3 Value

UpdateRecords() {
    GetRequest "AccessKeyId=`enc "$AccessKeyId"`&Action=UpdateDomainRecord&Format=JSON&RR=`enc "$1"`&RecordId=`enc "$2"`&RegionId=cn-hangzhou&SignatureMethod=HMAC-SHA1&SignatureNonce=`date +%s%N`&SignatureVersion=1.0&Timestamp=`enc "$timestamp"`&Type=A&Value=`enc "$3"`&Version=2015-01-09"
}


#增加域名记录信息
#$1 主机名称
#$2 Value 

AddRecords() {
    GetRequest "AccessKeyId=`enc "$AccessKeyId"`&Action=AddDomainRecord&DomainName=`enc "$DomainName"`&Format=JSON&RR=`enc "$1"`&RegionId=cn-hangzhou&SignatureMethod=HMAC-SHA1&SignatureNonce=`date +%s%N`&SignatureVersion=1.0&Timestamp=`enc "$timestamp"`&Type=A&Value=`enc "$2"`&Version=2015-01-09"
}

#循环执行
while(true)  
do  
####获取当前时间
#timestamp=`date -u "+%Y-%m-%dT%H%%3A%M%%3A%SZ"`
    timestamp=`date -u "+%Y-%m-%dT%H:%M:%SZ"`
####获取当前公网IP
    CurrentIp=`curl -s whatismyip.akamai.com 2>&1` || ErrorExit "curl" 1
   
    if [ "$CurrentIp" != "$PreIp" ] 
    then
#######循环主机名
       for ss in ${RRs[@]}
       do		
#######获取域名IP信息是否存在，存在更新，不存在新建  
          echo "Deal:$ss"
          curldata=`GetRecords $ss`
#         echo $curldata
          bExit=`echo -n $curldata | jq .TotalCount`
          if [ "$bExit" != "0" ]
          then
###############获取对比dns ip
               if [ "$PreIp" = "" ]
               then
               DnsIp=$(echo -n $curldata | jq '.DomainRecords.Record[0].Value' |tr -d "\"")   
               echo GetSet:$DnsIp 
               else
               DnsIp=$PreIp       
               fi

               if [ "$DnsIp" != "$CurrentIp" ]
               then
               RecordId=$(echo -n $curldata | jq '.DomainRecords.Record[0].RecordId' |tr -d "\"")
#              echo  $ss $RecordId $CurrentIp
               curldata=`UpdateRecords $ss $RecordId $CurrentIp`
               echo UpdateRecords:$curldata
               fi  
          else
##############增加需解析主机名称
               curldata=`AddRecords $ss $CurrentIp`
               echo  "AddRecords:$curldata" 
          fi
       done
       PreIp="$CurrentIp";
#   else
#      echo  "UnChange:$CurrentIp"
    fi 

#休眠一小时
 sleep 10
done  
