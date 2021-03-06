//+------------------------------------------------------------------+
//|                                                         Auth.mq4 |
//|                             Copyright 2019, fhfai Software Corp. |
//|                                      https://auth.weilian.org.cn |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, fhfai Software Corp."
#property link      "https://auth.weilian.org.cn"
#property version   "1.00"
#property strict
//--- input parameters
input string   title = "EA网络授权";
input string   key = "RGcwTWpWRlYzVFZSVmVrOVJhVmxVVVhoTlJFa3pUbFJPYWs1WFJUUlBSMGt4VDBSUk1WcFhSWGhaZWsxNVQwUk9iVmxxVVcxNGFGa3lkRE5hVjNoelVqSjRkbGx0Um5OTVZYaHdaRzFWTnpKbVpERXlNV00wWTJGa05UY3lNR1ZsTURNeE5ESm1aV00wTlRabE1EQWswTg";

#include "hash.mqh"
#include "json.mqh"

#import "wininet.dll"
int InternetAttemptConnect (int x);
int InternetOpenW(string sAgent, int lAccessType, string sProxyName = "", string sProxyBypass = "", int lFlags = 0);
int InternetOpenUrlW(int hInternetSession, string sUrl, string sHeaders = "", int lHeadersLength = 0,int lFlags = 0, int lContext = 0);
int InternetReadFile(int hFile, int& sBuffer[], int lNumBytesToRead, int& lNumberOfBytesRead[]);
int InternetCloseHandle(int hInet);
#import

// 使用wininet.h中的常量名
#define OPEN_TYPE_PRECONFIG     0           // 使用默认配置
#define FLAG_KEEP_CONNECTION    0x00400000  // 保持连接
#define FLAG_PRAGMA_NOCACHE     0x00000100  // 页面不缓存
#define FLAG_RELOAD             0x80000000  // 当连接时从服务器接收页面
#define SERVICE_HTTP            3           // 所需的协议

// 服务端api 接口 网址
string auth_url = "https://auth.weilian.org.cn/api/auth/verify/key/";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- 一小时检测一次授权状态
   EventSetTimer(3600);
   accountAuth(auth_url);

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
   delTag();
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
 
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   accountAuth(auth_url);
   
  }
//+------------------------------------------------------------------+


//  ------ 显示图表标签  ------
//  object_label_name 标签名称，x轴，y轴，data[]要显示的数据数组
int chartLabel(string object_label_name, int x, int y, const string & data[])
{
   int count = ArraySize(data);
   for(int i=0; i<count; i++){
     string object_label = object_label_name + StringFormat("%d",i);
     ObjectCreate(object_label, OBJ_LABEL, 0, 0, 0); //物件建立(標籤物件)
     ObjectSetText(object_label,data[i],10,"Arial",Yellow); //設定標籤物件文字,大小,字型,顏色
     ObjectSet(object_label, OBJPROP_XDISTANCE, x); //設定X軸距
     ObjectSet(object_label, OBJPROP_YDISTANCE, y + (i*30)); //設定Y軸距
   }
   return(true);
}

// ------ 删除图表中的标签 ------
void delTag(){
   for(int i=0; i<4; i++){      
       ObjectDelete(ObjectName(i));                
   }  
}

// 账户授权验证
int accountAuth(string url)
{
    if(!IsDllsAllowed())
     {      
       MessageBox("DLL权限没有打开","EA授权",0);
       return(0);
     }
   int rv = InternetAttemptConnect(0);
   if(rv != 0)
     {
       MessageBox("网络连接失败","EA授权",0);
        return(0);
     }
   int hInternetSession = InternetOpenW("Microsoft Internet Explorer", 0, "", "", 0);
   if(hInternetSession <= 0)
     {       
       MessageBox("访问网络失败","EA授权",0);
        return(0);
     }
   int hURL = InternetOpenUrlW(hInternetSession, url + key, "", 0, FLAG_KEEP_CONNECTION|FLAG_RELOAD|FLAG_PRAGMA_NOCACHE, 0);
   if(hURL <= 0)
     {
       MessageBox("网址无法访问","EA授权",0);
       InternetCloseHandle(hInternetSession);
        return(0);
     }      
   int cBuffer[256];
   int dwBytesRead[1]; 
   string auth_json = "";
   while(!IsStopped())
     {
       bool bResult = InternetReadFile(hURL, cBuffer, 1024, dwBytesRead);
       if(dwBytesRead[0] == 0)
       {
           break;
       }
       string text = "";   
       for(int i = 0; i < 256; i++)
         {         
           text = text + CharToStr(cBuffer[i] & 0x000000FF);
        	  if(StringLen(text) == dwBytesRead[0]){
        	      break;
        	  }
        	  text = text + CharToStr(cBuffer[i] >> 8 & 0x000000FF);
        	  if(StringLen(text) == dwBytesRead[0])
        	  {
        	      break;
        	  }
           text = text + CharToStr(cBuffer[i] >> 16 & 0x000000FF);
           if(StringLen(text) == dwBytesRead[0])
           {
               break;
           }
           text = text + CharToStr(cBuffer[i] >> 24 & 0x000000FF);
         }
       auth_json = auth_json + text;
       Sleep(1);
     }
     
    // Print(auth_json);
   
    // 解析json 数据
    JSONParser *parser = new JSONParser();
    JSONValue *jv = parser.parse(auth_json);
    if (jv == NULL) {
        Print("error:"+(string)parser.getErrorCode()+parser.getErrorMessage());
    } else {
        if (jv.isObject()) { // check root value is an object. (it can be an array)
            JSONObject *jo = jv;
            if(jo.getString("code") != "success")
            {
              MessageBox(jo.getString("message"),"EA授权失败",0);
              ExpertRemove();
            }
             // 检查授权是否过期
            if(TimeGMT() > StringToTime(jo.getString("close_day"))){
               MessageBox("EA授权已过期，过期时间：" + jo.getString("close_day"),"授权过期");
               ExpertRemove();
            }
            string account_number = StringFormat("%I64d",AccountNumber());
            if(jo.getString("account_number") != account_number) {
               MessageBox(jo.getString("message"),"交易账户不匹配，EA授权失败",0);
               ExpertRemove();
            }
            if(jo.getString("server") != AccountInfoString(ACCOUNT_SERVER)) {
               MessageBox(jo.getString("message"),"交易服务器不匹配，EA授权失败",0);
               ExpertRemove();
            }
           // 账户授权信息显示到图表
           string left_label_array[10];  
           left_label_array[0] = "EA授权验证：正版授权";
           left_label_array[1] = "授权账户：" + jo.getString("account_number");
           left_label_array[2] = "剩余天数：" + jo.getString("day");
           left_label_array[3] = "到期日期：" + jo.getString("close_day");
           chartLabel("left_label",10, 30, left_label_array);
   
        }
        delete jv;
    }
    delete parser;
    return(true);
}
 
 