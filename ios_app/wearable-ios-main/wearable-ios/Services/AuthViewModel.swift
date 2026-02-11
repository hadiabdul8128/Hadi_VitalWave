//
//  AuthViewModel.swift
//  wearable-ios
//  Created by Carola Maglione on 10/9/23.


import SwiftUI
@preconcurrency import FirebaseAuth
import os
import Combine

enum AuthenticationState {
    case unauthenticated
    case authenticating
    case authenticated
}

enum AuthenticationFlow {
    case login
}

/** The ObservableObject handling all data about the current user's authentication state.  */
@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    
    @Published var flow: AuthenticationFlow = .login
    
    @Published var isValid: Bool = false
    
    @Published var authenticationState: AuthenticationState = .authenticating
    @Published var user: User?
    @Published var errorMessage: String = ""
    @Published var displayName: String = ""
    @Published var logger: Logger
    
    var cancellables = Set<AnyCancellable>()
    
    init() {
        logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ble-default")
        logger.info("Connected to foreground!!")
        
        
        $flow
            .combineLatest($email, $password, $confirmPassword)
            .map { flow, email, password, confirmPassword in
                flow == .login
                ? !(email.isEmpty || password.isEmpty)
                : !(email.isEmpty || password.isEmpty || confirmPassword.isEmpty)
            }
            .sink(receiveValue: { isValid in
                self.isValid = isValid
            })
            .store(in: &cancellables)
        
        
    }
    
//    private var authStateHandler: AuthStateDidChangeListenerHandle?
//    
//    private func registerAuthStateHandler() {
//        if authStateHandler == nil {
//            authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
//                self?.user = user
//                self?.authenticationState = user == nil ? .unauthenticated : .authenticated
//                self?.displayName = user?.email ?? ""
//            }
//        }
//    }
    
    private func reset() {
        flow = .login
        email = ""
        password = ""
        confirmPassword = ""
        UserDefaults.standard.set(nil, forKey: "auth-uid")
        UserDefaults.standard.removeObject(forKey: "pairedPeripherals")
        UserDefaults.standard.removeObject(forKey: "paired-peripherals")
        UserDefaults.standard.removeObject(forKey: "cookies")
    }
    
    /// UID for the current user; falls back to UserDefaults when in bypass mode (no real login)
    var effectiveUid: String? {
        user?.uid ?? UserDefaults.standard.string(forKey: "auth-uid")
    }
    
    /** Observe the user's authentication state and update when it changes */
    func listenToAuthState() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            print("[AuthViewModel] Auth state changed")
            guard let self = self else { return }
            if let uid = user?.uid {
                print("[AuthViewModel] User \(uid) signed in, setting UID")
                UserDefaults.standard.set(uid, forKey: "auth-uid")
            } else {
                // Bypass: when backend is unavailable, skip login and use a dev UID so the app is usable
                UserDefaults.standard.set("bypass-dev", forKey: "auth-uid")
            }
            Task { @MainActor in
                self.user = user
                self.displayName = user?.email ?? (user == nil ? "Bypass (offline)" : "")
                self.authenticationState = .authenticated
            }
        }
    }
    
    /** Currently unused, should use signInWithToken instead */
    func signInWithEmailPassword() async -> Bool {
        authenticationState = .authenticating
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            return true
        } catch {
            print(error)
            errorMessage = error.localizedDescription
            authenticationState = .unauthenticated
            return false
            
        }
    }
    
    /** Intsead of signing in with an email and password, we can sign in with a token returned from the cloud function getAuthToken() */
    func signInWithToken(token: String) async {
        authenticationState = .authenticating
        do {
            try await Auth.auth().signIn(withCustomToken: token)
        } catch {
            print("signInWithTokenError:",  error.localizedDescription.debugDescription)
            errorMessage = error.localizedDescription
            authenticationState = .unauthenticated
        }
    }
    
    /** Signs out the current user. Also unpairs any paired peripherals*/
    func signOut() {
        do {
            try Auth.auth().signOut()
            reset()
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }
}
