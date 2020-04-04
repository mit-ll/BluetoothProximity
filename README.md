# BluetoothProximity

This is an iOS application built to primarily log information from the Bluetooth receiver on iPhones. In addition, it can log the state of the proximity sensor, accelerometers, gyroscope, and location services.

The logged data will be used to develop detection algorithms to determine if you have been in proximity of another Bluetooth device for a certain period. The intent is to do so with completely anonymized data.

A very basic version of the detection logic also runs on the iPhone on live data, updating on the screen as it comes in. This information is strictly for debugging.

## Supported Devices

It's very likely this application will run on all newer iPhones, but has only been tested thus far on an iPhone SE. More devices coming soon. 

The debugging interface displayed on the phone's screen may not scale well for larger/smaller screens (relative to the iPhone SE).

## Instructions

Running this app may be denied since it is not trusted. Go to settings, general, profiles & device management. Under developer app click mchlwntz@gmail.com and trust it.

On first launch, approve use of Bluetooth and allow use of location while using the app. When you close the app you will also get a notification about using location even when the app is not in use; change to always allow.

Upon launching the app, data will immediately start logging to a text file on the phone. The top of the app shows a status message and will indicate if the Bluetooth radio is off - if it is off, please turn it on. You can do this by swiping up and clicking the Bluetooth icon while the app is running, no need to restart it. 

The app will display the total number of Bluetooth messages logged. Keep the app open and on screen while you are doing measurements - do not put it in the background. After you have done your measurements, click the "Send Log" button to share the data. Typically I email the data to myself to process on my computer. Afer you are done, close it like you would any normal app.

The app currently logs to a file always named log.txt, and this file is created each time the app is launched. If you forget to send your log file and close the app, the next opening of the app will immediately overwrite the log file!

## Building

This appplication was built using Xcode 10.1 on macOS 10.13.6, but is likely to work with other versions (possibly with syntax changes). By default you should be able to build the project and run it on an iPhone attached to a computer. Building and running is as simple as clicking the play arrow in the Xcode IDE.

Note that with the recent versions of Xcode, you can deploy and run the app on your device over a WiFi network. To do so, attach your phone using the USB cable and go to Window and then Devices and Simulators. Select your device on the left, then in the top right panel check the box to Connect via network. You should see now see the network icon next to your device.

## Known Issues

These messages appear in the Xcode console when using the "Send Log" button to email the log file to yourself. They do not appear to affect anything, as the log file still goes through.
```
[core] SLRemoteComposeViewController: (this may be harmless) viewServiceDidTerminateWithError: Error Domain=_UIViewServiceErrorDomain Code=1 "(null)" UserInfo={Terminated=disconnect method}
[ShareSheet] connection invalidated
```