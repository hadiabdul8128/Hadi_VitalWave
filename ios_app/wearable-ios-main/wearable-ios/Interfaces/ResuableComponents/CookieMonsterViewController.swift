//
//  CookieMonsterViewController.swift
//  wearable-ios
//
//  Created by Luke Redmore on 4/19/24.
//

import WebKit

/// This View Controller contains just a special, dashboard-page cookie-persisting WKWebView (called CookieMonster) and a centered loading spinner. All this class does is layout those two views and loads saved cookies into the webView.
///
/// # Important
/// If you override the WKNavigationDelegate in a sublass, make sure to call the superclass method of `webView(_ webView: WKWebView, didFinish navigation: WKNavigation!)`. Otherwise, cookies will NOT be saved:
/// ```swift
/// override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
///     super.webView(webView, didFinish: navigation)
///     // ...Rest of function
/// }
/// ```
class CookieMonsterViewController: UIViewController, WKNavigationDelegate {
    let webView = CookieMonster(listeningAtPath: "/dashboard")
    let activityIndicator = UIActivityIndicatorView()
    
    init() {
        super.init(nibName: nil, bundle: nil)
        self.webView.navigationDelegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /** Lays out the WKWebView and UIActivityIndicatorView (i.e. spinner). One of either the WKWebView or spinner will always be shown */
    override func loadView() {
        view = UIView()
        
        // Create and layout WKWebView
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Create and layout UIActivityIndicatorView
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = .gray
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.webView.storeCookies()
    }
}
