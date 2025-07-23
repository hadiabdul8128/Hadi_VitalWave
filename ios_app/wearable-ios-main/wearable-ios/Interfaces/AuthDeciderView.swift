//
//  AuthDeciderView.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/12/23.
//

import SwiftUI

struct GetSignInTokenRequest: Codable {
    var token: String
}

/** A simple view to display the login page if no user, or the MainView if a user is logged in */
struct AuthDeciderView: View {
    @StateObject private var authModel = AuthViewModel()
    var body: some View {
        Group {
            switch authModel.authenticationState {
                case .authenticated: MainTabView()
                case .unauthenticated: LoginWebView { result in
                    switch result {
                        case .success(let idToken): onIdTokenReceived(idToken: idToken)
                        case .failure(let error): print(error)
                    }
                }.ignoresSafeArea()
                case .authenticating: ProgressView().ignoresSafeArea()
                
            }
        }.onAppear{
            authModel.listenToAuthState()
        }.environmentObject(authModel)
    }
    
    /** Once the login web view returns the idToken, we then use that to request an authToken from CloudFunctions via a POST request.
     *  If fetching the auth token is successful, then it is used to sign in the user */
    private func onIdTokenReceived(idToken: String) {
        Task {
            let authTokenResult: (Result<String, Error>) = await APIManager.sendRequest(
                method: "POST",
                url: "https://us-central1-bc-infection-detection.cloudfunctions.net/getAuthToken",
                parameters: GetSignInTokenRequest(token: idToken)
            )
            switch authTokenResult {
                case .success(let authToken): await authModel.signInWithToken(token: authToken)
                case .failure(let error): print(error)
            }
        }
    }
}

#Preview {
    AuthDeciderView()
}
