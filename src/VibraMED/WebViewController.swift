//
//  WebViewController.swift
//  VibraMED
//
//  Created by Valeriy Akimov on 18.03.2021.
//

import UIKit
import WebKit

class WebViewController: UIViewController, WKUIDelegate, WKNavigationDelegate{


    // WKWebViewConfiguration
    let configuration = WKWebViewConfiguration()
    
    var webView: WKWebView!
    public var base:CameraViewController!
    public var httpResponse:HTTPURLResponse!
    private var loadRequest:URLRequest!
    
    override func loadView() {
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        view = webView
    }
    

    private func load() {
        if(webView != nil && loadRequest != nil) {
            webView.load(loadRequest)
        } else {
            base.httpHelper.onStart()
        }
    }
    
    public func preStart() {
        loadRequest = nil
        retrieve_cookies()
    //    self.base.httpHelper.httpCookies = [:]
    }
    
    public func load(_ url: String) {
        let myURL =  URL(string: url )
        let myRequest = URLRequest(url: myURL!)
        httpResponse = nil
        loadRequest = myRequest
        retrieve_cookies()
    }

    public func load(_ url: String, withData data:String) {
        let myURL =  URL(string: url )
        var myRequest = URLRequest(url: myURL!)
        myRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        myRequest.httpMethod = "POST"
        myRequest.httpBody = data.data(using: .utf8)
        
        httpResponse = nil
        loadRequest = myRequest
        retrieve_cookies()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        let ds = WKWebsiteDataStore.default()
        let cookies = ds.httpCookieStore
        self.base.httpHelper.httpCookies = [:]
        cookies.getAllCookies { (cookies: [HTTPCookie]) in
            for cookie in cookies {
                NSLog("Known cookie at load: \(cookie.name)")
            }
        }
        NSLog("Starting to load")
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

        if let httpResponse = navigationResponse.response as? HTTPURLResponse {
            self.httpResponse =  httpResponse
        } else
        {
            httpResponse = nil
        }

        decisionHandler(.allow)
    }
   
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let url = (webView.url?.absoluteString)!
        
        NSLog("Load finished")
        let ds = WKWebsiteDataStore.default()
        let cookies = ds.httpCookieStore
        cookies.getAllCookies { (cookies: [HTTPCookie]) in
            var cookieDict = [String : AnyObject]()
            for cookie in cookies {
                NSLog("Saved cookie: \(cookie.name)")
                
                cookieDict[cookie.name] = cookie.properties as AnyObject?
                
                self.base.httpHelper.httpCookies[cookie.name] = cookie.value
            }
            UserDefaults.standard.set(cookieDict, forKey: "cookies")
            self.onHttpFinish(url)
        }

    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let url = (webView.url?.absoluteString)!
        onHttpError(url,withError: error)
    }
    
    public func onHttpFinish(_ url:String) {
        self.base.httpHelper.onPageFinished(self, withUrl: url )
    
    }

    public func onHttpError(_ url:String, withError error: Error) {
        
    }
    
    public func retrieve_cookies()
    {
        let ds = WKWebsiteDataStore.default()
        let cookies = ds.httpCookieStore
        let userDefaults = UserDefaults.standard
        self.base.httpHelper.httpCookies = [:]
 
        if let cookieDict = userDefaults.dictionary(forKey: "cookies") {
            NSLog("Retrieving cookies")
            var cookies_left = 0
            for (_, cookieProperties) in cookieDict {
                if let _ = HTTPCookie(properties: cookieProperties as! [HTTPCookiePropertyKey : Any] ) {
                    cookies_left += 1
                }
            }
            
            for (cname, cookieProperties) in cookieDict {
                
                if let cookie = HTTPCookie(properties: cookieProperties as! [HTTPCookiePropertyKey : Any] ) {
                    
                    cookies.setCookie(cookie, completionHandler: {
                        cookies_left -= 1
                        NSLog("Retrieved cookie, \(cname) to go")
                        if self.base.httpHelper.nLoad != 0 || cookie.name != "vibra_login_hash" {
                            self.base.httpHelper.httpCookies[cookie.name] = cookie.value
                        }
                        if cookies_left == 0 {
                            self.load()
                        }
                    })
                }
                
            }
        } else {
            NSLog("No saved cookies")
            self.load()
        }
    }
    
}
