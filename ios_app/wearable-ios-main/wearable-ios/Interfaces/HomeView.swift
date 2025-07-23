//
//  ContentView.swift
//  wearable-ios
//
//  Created by Luke Redmore on 9/18/23.
//

import SwiftUI
import WebKit

/// This view shows the dashboard web app while persisting the authentication state so that the user does not need to login again
struct HomeView : UIViewControllerRepresentable {
    typealias UIViewControllerType = DashboardWebViewController
    @EnvironmentObject private var authModel: AuthViewModel
        
    func makeUIViewController(context: Context) -> UIViewControllerType {
        return DashboardWebViewController(authModel: authModel)
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }
}

/// ViewController underlying `HomeView`
class DashboardWebViewController: CookieMonsterViewController {
    private let authModel: AuthViewModel
    private var refreshingSession = false
    
    init(authModel: AuthViewModel) {
        self.authModel = authModel
        super.init()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isHidden = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        activityIndicator.startAnimating()
        webView.load(URLRequest(url: URL(string: "https://v2-dot-bc-infection-detection.uc.r.appspot.com/dashboard")!))
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func url(_ url: URL?, hasPath path: String) -> Bool {
        guard let url = webView.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.path == path else { return false }
        return true
    }
    
    // Show web view on loading finish, unless its the login page
    override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        super.webView(webView, didFinish: navigation)
        if url(webView.url, hasPath: "/") { return }
        
        let topPadding = Int(webView.safeAreaInsets.top)
        if url(webView.url, hasPath: "/dashboard") {
            webView.evaluateJavaScript("""
                // Remove sidebar
                const menuToggle = document.querySelector('div.menu-toggle');
                if (menuToggle) { menuToggle.remove(); }
            
                // Remove top banner
                const topBanner = document.querySelector('div.top-banner');
                if (topBanner) { topBanner.remove(); }
            
                // Expand padding of green banner so to preserve time, etc on phone
                const fixedBanner = document.querySelector('div.fixed-banner');
                if (fixedBanner) { 
                    fixedBanner.style.paddingTop = '\(topPadding)px'; 
                    fixedBanner.style.flexDirection = 'column';
                    fixedBanner.style.width = '100vw';
                }
            
                // Remove extra padding added to accommodate sidebar
                const content = document.querySelector('div.content');
                if (content) { content.style.marginLeft = '0px'; }
            
                // Additional styles to make it look better on mobile (TODO: incorporate on webapp itself)
                const iFrameContainer = document.querySelector('div.content div.iframe-container');
                if (iFrameContainer) { iFrameContainer.style.margin = 0; }
            
                const metricContainer = document.querySelector('div.content div.metric-container');
                if (metricContainer) { 
                    metricContainer.style.flexDirection = 'column';
                    metricContainer.style.margin = 0;
                    metricContainer.style.padding = '10px';
                    metricContainer.style.gap = '10px';
            
                    // Set each child element's width to 100%
                    const children = metricContainer.children;
                    for (let i = 0; i < children.length; i++) {
                        children[i].style.width = '95vw';
                    }
                }
            
                const centeredElement = document.querySelector('div.fixed-banner div.centered-element');
                if (centeredElement) {
                    centeredElement.style.position = 'static';
                    centeredElement.style.transform = 'unset';
                } 
            
            
                const rightElement = document.querySelector('div.fixed-banner div.right-aligned-element');
                if (rightElement) {
                    rightElement.style.width = 'unset';
                    rightElement.children[0].style.maxWidth = '200px';
                }
            
                
            """)
        }
        
        webView.isHidden = false
        activityIndicator.stopAnimating()
    }
    
    // If login page starts loading, hide the webView and refresh the session
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if url(webView.url, hasPath: "/") {
            print("DashboardWebView logged out! Lets get an auth token and refresh the session")
            webView.isHidden = true
            activityIndicator.startAnimating()
            refreshSession()
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        // TODO: Prevent navigating away from dashboard?
        return .allow
    }
}

extension DashboardWebViewController {
    enum RefreshWebSessionError: Error {
        case noUser
        case unknown
    }
    
    /// Reauthenticate the logged in app user on the web app by getting an auth token from Cloud Functions and signing into the web app with it
    private func refreshSession() {
        guard refreshingSession == false else { return }
        self.refreshingSession = true
        Task { [weak user = authModel.user] in
            do {
                let idToken = try await user?.getIDToken()
                guard let idToken = idToken else { throw RefreshWebSessionError.noUser }
                print("Refreshed idToken: \(idToken)")
                
                let authTokenResult: (Result<String, Error>) = await APIManager.sendRequest(
                    method: "POST",
                    url: "https://us-central1-bc-infection-detection.cloudfunctions.net/getAuthToken",
                    parameters: GetSignInTokenRequest(token: idToken)
                )
                if case .failure(let error) = authTokenResult { throw error }
                guard case .success(let authToken) = authTokenResult else { throw RefreshWebSessionError.unknown }
                print("Used idToken to fetch authToken: \(authToken)")
                
                try await self.webView.evaluateJavaScript("""
                    firebase.auth().signInWithCustomToken("\(authToken)").then((userCredential) => {
                        userCredential.user.getIdToken().then((idToken) => {
                            // Send token to your backend via HTTP
                            fetch('/login', {
                                method: 'POST',
                                headers: {
                                    'Content-Type': 'application/json',
                                },
                                body: JSON.stringify({ id_token: idToken })
                            }).then(response => {
                                if (response.ok) {
                                    return response.json();
                                } else {
                                    throw new Error('Failed to log in');
                                }
                            }).then(data => {
                                if (data.status === 'success') {
                                    window.location.href = '/dashboard';
                                } else {
                                    alert('Failed to log in: ' + data.message);
                                }
                            }).catch(error => {
                                console.error('Error sending token to backend:', error);
                            });
                        });
                      }).catch((error) => {
                        console.error('Error logging in user:', error);
                        alert('Error logging in user: ' + error.message);
                      });
                """)
            } catch {
                print("Could not refresh session:", error)
            }
            self.refreshingSession = false
        }
    }
}
