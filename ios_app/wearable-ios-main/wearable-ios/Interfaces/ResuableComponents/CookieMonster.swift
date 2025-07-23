//
//  CookieMonster.swift
//  wearable-ios
//
//  Created by Luke Redmore on 4/19/24.
//

import WebKit

/// Cookie Monster is a special kind of WKWebView that saves all the cookies of the WKWebView when a certain path is reached
///
/// # Important
/// When setting the WKNavigationDelegate, you must call `cookieMonster.storeCookies()` at the beginning of `webView(_ webView: WKWebView, didFinish navigation: WKNavigation!)`. Otherwise, cookies will NOT be saved:
/// ```swift
/// func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
///     (webView as? CookieMonster)?.storeCookies()
/// }
/// ```
class CookieMonster: WKWebView {
    private let path: String
    
    init(listeningAtPath path: String) {
        self.path = path
        super.init(frame: .zero, configuration: CookieMonster.createWKWebViewConfigWithSavedCookies())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func storeCookies() {
        guard let url = self.url,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.path == path else { return }
            
        self.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            print("Found cookies", cookies)
            CookieMonster.saveSessionCookiesToDisk(cookies)
        }
    }
    
    private static func saveSessionCookiesToDisk(_ cookies: [HTTPCookie]) {
        let cookiesData = try! NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: false)
        UserDefaults.standard.set(cookiesData, forKey: "cookies")
        print("Saved cookies to disk!")
    }


    private static func loadSessionCookiesFromDisk() -> [HTTPCookie]? {
        if let data = UserDefaults.standard.value(forKey: "cookies") as? Data,
           let cookies = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [HTTPCookie] {
            return cookies
        } else {
            print("CookieMonster could not load cookies from disk")
        }
        return nil
    }
    
    
    private static func createWKWebViewConfigWithSavedCookies() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        if let cookies = loadSessionCookiesFromDisk() {
            for cookie in cookies {
                config.websiteDataStore.httpCookieStore.setCookie(cookie)
            }
            print("Injected disk cookies into CookieMonster web view")
            
        } else {
            print("No saved cookies found")
        }
        return config
    }
}
