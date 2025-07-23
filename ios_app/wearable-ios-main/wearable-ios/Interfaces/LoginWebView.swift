//
//  LoginWebView.swift
//  DukeSakai
//
//  Created by Luke Redmore on 8/12/22.
//

import SwiftUI
import WebKit

/** Error states returned by AuthWebView completion Result */
enum LoginWebViewError: Error {
    case canceled
    case unknown
    case idTokenError(message: String)
}

/** This view loads the login page for the dashboard and returns the logged in user's ID token immediately after login. This ID token can then be used on the server side to verify that a request is coming from an authenticated user */
struct LoginWebView : UIViewControllerRepresentable {
    typealias UIViewControllerType = LoginWebViewController
    
    /** After successful login, return the result of asking the browser for the logged in user's ID token. This ID token can then be used on the server side to verify that a request is coming from an authenticated user */
    let completion: (Result<String, LoginWebViewError>) -> Void
    
    func makeUIViewController(context: Context) -> UIViewControllerType {
        return LoginWebViewController(completion: completion)
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }

}

/** The underlying ViewController controlling AuthWebView */
class LoginWebViewController: CookieMonsterViewController, WKScriptMessageHandler {
    private let completion: (Result<String, LoginWebViewError>) -> Void
    
    init(completion: @escaping (Result<String, LoginWebViewError>) -> Void) {
        self.completion = completion
        super.init()
        
        webView.navigationDelegate = self
        webView.configuration.userContentController.add(self, name: "onIdTokenReceived")
        webView.configuration.userContentController.add(self, name: "onIdTokenError")
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.load(URLRequest(url: URL(string: "https://v2-dot-bc-infection-detection.uc.r.appspot.com/login")!))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Hide web view and show spinner on page loading (makes it feel more native)
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        webView.isHidden = true
        activityIndicator.startAnimating()
    }
    
    // When a page is done loading, this function first checks if the login is successful (i.e. the /dashboard page is reached) or if some other page is reached. If on the dashboard, it then executes Javascript in the web view to get the user's id token
    override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        super.webView(webView, didFinish: navigation)
        
        if let url = webView.url,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
           components.path == "/dashboard" {
            
            // Need to delay this just a bit, else "firebase" isn't defined
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                webView.evaluateJavaScript(
                """
                    firebase.auth().currentUser.getIdToken(true)
                        .then(token => { window.webkit.messageHandlers.onIdTokenReceived.postMessage(token) })
                        .catch(err => { window.webkit.messageHandlers.onIdTokenError.postMessage(err.message) })
                """)
            }
        } else {
            webView.isHidden = false
            activityIndicator.stopAnimating()
        }
    }
    
    // The result (or error) of asking for the id token is handled here, and the result is returned to the completion handler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "onIdTokenReceived", let idToken = message.body as? String {
            completion(.success(idToken))
        } else if message.name == "onIdTokenError", let errorMessage = message.body as? String {
            completion(.failure(.idTokenError(message: errorMessage)))
        } else {
            completion(.failure(.unknown))
        }
    }
}
