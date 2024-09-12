//
//  HttpHelper.swift
//  VibraMED
//
//  Created by Valeriy Akimov on 18.03.2021.
//

import Foundation
import UIKit
import WebKit

class HttpHelper {
    private var base:CameraViewController!
    public var mMeasureStart:Int
    public var httpCookies: Dictionary<String, Any> = [:]
    public var bStarted:Bool = false
    public var nLoad : Int = 0
    
    init(_ base:CameraViewController) {
        self.base = base
        mMeasureStart =  0
    }
    
    public func getCookie(_ tag:String) -> String {
        let v = httpCookies[tag]
        if v != nil {
            return v as! String
        }
        return ""
    }

    func getQueryStringParameter(url: String, param: String) -> String? {
        guard let url = URLComponents(string: url) else { return nil }
        return url.queryItems?.first(where: { $0.name == param })?.value
    }
    public func TestLogin() -> Bool{
        let login_hash =  getCookie("vibra_login_hash")
        return  self.nLoad > 0 && login_hash.count > 0;
    }

    public func TestBalance() -> Bool {
        let login_balance = getCookie("vibra_login_balance")
        return login_balance.count > 0 && Int(login_balance) ?? 0 > 0
   }

    public func getCurrentLanguage() -> String{
        return "en"
    }
    
    public func urlBase() -> String {
        return base.engine.localizedString(forKey: "VI_INFO_SITE_URL_BASE")
    }
    
    public func urlMeasure() -> String {
        return urlBase() + "?cmd=measure&lang=" + getCurrentLanguage()
    }
    
    public func hostBase() -> String {
        if let url = URL(string: urlBase() )  {
            return url.host!
        }
        return ""
    }
    public func navigateStart() {
        let webViewController = WebViewController()
        webViewController.base = base
        webViewController.preStart()
    }
    public func navigateLogin(_ bAuto:Bool) {
        let webViewController = WebViewController()
        webViewController.base = base
        base.present(webViewController, animated: true)
        
        var url:String = urlBase()
        url += (url.contains("?") ? "&" : "?") + "cmd=login&lang="+getCurrentLanguage()
        if(!bAuto) {
            url+="&noredirect"
        }
        webViewController.load(url)
    }
    public func navigateBalance() {
        let webViewController = WebViewController()
        webViewController.base = base
        base.present(webViewController, animated: true)
        
        var url:String = urlBase()
        url += (url.contains("?") ? "&" : "?") + "cmd=pay&lang="+getCurrentLanguage()

        webViewController.load(url)
   }
   public func navigateResults() {
        let webViewController = WebViewController()
        webViewController.base = base
        base.present(webViewController, animated: true)
        
        var url:String = urlBase()
        url += (url.contains("?") ? "&" : "?") + "cmd=results&lang="+getCurrentLanguage()

        webViewController.load(url)
    }

    public func navigatePost(_ url:String, withData data:String) {
        let webViewController = WebViewController()
        webViewController.base = base
        base.present(webViewController, animated: true)
        webViewController.load(url,withData: data)
        
    }
    
    public func onPageFinished(_ wc:WebViewController, withUrl url:String) {

        let cmd = getQueryStringParameter(url: url,param: "cmd")
        if(cmd == nil || cmd == "") {
        //    base.present(base.webViewController, animated: true)
            return;
           }
  
 
        
        if(cmd == "measure") {
         //   base.present(base.webViewController, animated: true)
        }
        if(cmd ==  "login") {
            let prm_nr = getQueryStringParameter(url: url,param: "noredirect")
            let bAuto = (prm_nr == nil || prm_nr == "")
            if (TestLogin() && bAuto) {
                wc.dismiss(animated: true, completion: nil)
            }
            else {

            }
        }
        self.nLoad = self.nLoad + 1;
       }

       // Method to encode a string value using `UTF-8` encoding scheme
    private static func encodeValue(_ value:String)-> String {
        let escapedString = value.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
        return escapedString ?? ""
    }

    public func isStarted() -> Bool {
        return false
    }
    public func onMeasureStart() {
           mMeasureStart += 1
        
           if(mMeasureStart == 1) {
               if (TestLogin())
               {
                    if(isStarted()) {
                        self.base.engine.jni.measureAbort()
                    }
                    else
                    if( TestBalance() ) {
                        let login = HttpHelper.encodeValue(getCookie("vibra_login"))
                        
                        self.base.engine.jni.enginePutStrt("VI_INFO_SITE_LOGIN",and_v: login);
                        self.base.engine.jni.enginePutStrt("VI_INFO_SITE_PWD",and_v: getCookie("vibra_login_hash"));

                    //   self.base.engine.jni.enginePutFt("VI_INFO_M_DELAY",and_v: 1);
                    //    self.base.engine.jni.enginePutFt("VI_INFO_M_PERIOD",and_v: 6);

                        self.base.engine.jni.measureStart();
                    } else {
                        navigateBalance();
                    }
                } else {
                    navigateLogin(false);
                }
                
           }
 
        mMeasureStart-=1
    }


   public func onMeasureEnd() {
 //          if(jni.isDemo()) {
    //              jni.resetSeq(); }
   }
   
    public func onStart() {        
        if true || !TestLogin()
        {
            navigateLogin(false)
        }
        
        bStarted = true
    }
    


}
