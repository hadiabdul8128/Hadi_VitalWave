
# VitalSense 2023-25 Wearable Companion App
This iOS application is intended to be used with the biometric-tracking wearable developed in tandem.

Use this app to pair to one (or more) wearable devices via the BLE protocol. Then, the wearable will automatically transmit the data it collects to this app before saving it to disk and/or uploading it to Firebase Firestore.

## Requirements

- iOS 17.0+
- Xcode 15.0+

## Setup, Install, and Run On Device via Xcode
This is the best option if you would like to try running the app as you are editing it. If you only intend to run the app as is, please install it from **TestFlight**

*NOTE: This app should NOT be run via the Xcode simulator or SwiftUI Previews. It relies on the BLE capabilities of iOS, which are only available on a real device.*

1. Clone the repo

```
git clone git@gitlab.oit.duke.edu:big-ideas-wearable/wearable-ios.git
```
2. Double-click the `wearable-ios.xcodeproj` file to open the project in Xcode
3. If your Xcode is not signed in to an Apple ID with access to the Bass Wearable iOS App on App Store Connect, you may need to change the bundle identifier in order to sign and run the app. Please change it back before pushing any commits!
4. Plug in your iOS device to your computer. Click "Trust" and enter your passcode if prompted
5. If this is the first time installing the app via Xcode, you may also need to enable Developer Mode on your device via Privacy & Security > Developer Mode


## Deploy to TestFlight
*NOTE: You must have a Developer role or higher (and be signed into Xcode) on the Bass Wearable iOS app under the ThermaSENSE Corp. organization on App Store Connect to be able to deploy to TestFlight*

1. Increment the version number in the `Config` file according to [semantic versioning](https://semver.org/)
2. Click "Product > Archive" to build the app for TestFlight release
3. Once built, a window will appear with the newly built version hightlighted. Click "Distribute," then "TestFlight Internal Only"
4. After a few minutes, go to the Bass Wearable iOS app in App Store and click "TestFlight". You should see the new version there.
5. If there is a yellow warning icon ("Missing Compliance"), you just need to certify that the app does not use any encryption protocols
6. The newly released version should be available to internal testers via TestFlight! It is recommended that you "expire" the previous version so as to not confuse testers.

## Architecture Overview / File Structure
The source code of the app is organized into 3 top-level folder structures:

*Testing-Debug-Legacy*: Code not in use in the 'release' scheme of the application. However, when built from Xcode various legacy device connection protocols and deprecated views/components are available in here.

*Interfaces*: Code defining all of the SwiftUI views. This is a good starting point if unfamiliar with the project. The app launches into the `AuthDeciderView`, displaying the `MainTabView` if a user is logged in or the `LoginWebView` if not. The `MainTabView` creates a tab-based interface to access all the essential features of the app. The remaining code for their UI elements is found in the subfolders of *Interfaces*.

*Services*: This code defines pretty much everything else that is not a UI element, including the Firebase networking code, local file management, and the BLE data transfer code.

## Interfaces
- Main App Views: 
	Auth Decider View,
	Login Web View, 
	Main Tab View,
	Home View,
	Help View,
	Setting View,


- Live Data: 
    all of these views relate to the data views that a user sees once a device is connected. All the data visualization processing is done in the files within this project folder 


- Devices: 
    this folder handles all the views related to the device details and settings. These are not apart of the main view because they require an extra click to navigate to these views, thus they are contained in their own folder. All firebase and local storage enabling (view/logic trigger) is handled in this folder



## Programming Style
In Swift, there are many ways to handle UI and views within a project. The two main are through storyboards or programatically. 

The following project handles UI and views programatically for greater control and easier collaboration/sharing between developers. 

If you are new to swift or new to programatical UI structure that swift uses, the following guides were found to be extremely helpful: 
    https://medium.com/@avijeetpandey25/getting-started-with-creating-ui-programmatically-in-ios-using-swift-db83692b2363
    https://dev.to/msa_128/how-to-create-custom-views-programmatically-2cfm
    https://medium.com/poqcommerce/programmatic-views-consistently-better-user-interfaces-8b5496c4f134
    
## Supporting a new data type
This app has been designed to make it possible to support a new data type without changing too much code. Everything needed to do this can be found in [Services/Bluetooth/DataTransferModels/SampleData.swift]
