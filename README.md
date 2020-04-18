# BluetoothProximity

This is a basic iOS application that was built to log information from the Bluetooth receiver and other sensors on iPhones. The purpose of logging the data is to undertand the Bluetooth radio propagation channel between devices in everyday use. By collecting this data, algorithms can be developed that use knowledge of the phone's state, along with the Bluetooth Received Signal Strength Indicator (RSSI), to determine if a Bluetooth device is close or far away.

At a basic level, the RSSI decreases proportionally to the square of the distance between the transmitter and receiver. With knowledge of the transmitter power, the RSSI gives insight into the path loss, and thus the range. However, when a phone is in a pocket or masked by the body, the path loss can be much larger. By using this app to collect data in different scenarios, we hope to design a proximity detector with a high probably of detection and low probability of false alarm.

One first launch, approve the use of Bluetooth and allow location services (logging GPS is optional, as you will notice).

## Contact

BlueProximity@ll.mit.edu

This is a listserv which attempts to prevent spam being posted. After sending to it, you may receive an email saying that confirmation is required to post your message. Just click the link to approve the message (no need to reply), and you should get a follow up that your message was successfully posted.

As an alternative, you can always open an issue on GitHub.

## Logger Tab

The logger tab is the main interface for collecting data, and requires using two phones for controlled measurements. The basic process (on both phones) is:

1. Create a new log using the button at the top
2. Configure a collection:
	- Optionally enable recording of raw GPS data
	- Set the range between the two phones (measure it!)
	- Set the angle between the two phones, from the receiver's prospective (0 degrees = facing the transmitter) (measure it!)
	- Hit the run button to start collecting data. 
	- The counters below the button should start incrementing when both phones are running. BlueProx shows an RSSI count for the transmitting device under test, and Other shows the RSSI count for all other Bluetooth devices discovered.
	- Hit the button again to stop collecting data
3. Repeat step 2 as many times as desired, at various ranges and angles
4. Click the send log button at the bottom to open the sharing interface, where you can email the data to yourself or someone else. Make sure to include a description of what the test was in the email (indoor, outdoor, phone in a pocket, etc.).
5. Start over from step 1 to carry out another test, for example in a different environment.

See below for a description of the log file format (or take a look at the source code!).

<img src="Screenshots/logger.jpg" width="30%">

## Detector Tab

The detector tab shows a table of devices, their current RSSI, and if they are predicted to be close or far. Start and stop the live view using the button at the top. While the live view is running, the device will advertise the BlueProxTx name (in addition to scanning), so you can use this screen as the "transmit" phone during logging experiments if desired.

A close/far decision with a ? indicates that there isn't enough data to make a decision yet. Please note that the decisions reported here are the example of a toy algorithm (an M-of-N detector with low value of N) and the primary purpose is for debugging. The detector tab will serve as a playground of sorts to prototype new algorithms, some of which may use sensor information along with the RSSIs for an improved result.

<img src="Screenshots/detector.jpg" width="30%">

## Log Format

Timestamped data is written to the log in a comma separated way. The general format is:

```
Timestamp, sensor name, sensor values
```

Here's a description of the data after a timestamp:

```
Device, device model, device name
Range, value in feet
Angle, value in degrees
Bluetooth, UUID, RSSI, advertised name, TX power level, advertised timestamp
Accelerometer, x, y, z
Gyroscope, x, y, z
Proximity, enabled or disabled
GPS, latitude, longitude, altitude, speed, course
```

## Installation

The methods to install the app are:
- Build from source (with Xcode)
- Ad-hoc distribution (send me your device ID)
	- Once I have your device ID I'll upload a new build, and you can visit the [Wiki](https://github.com/mchlwntz/BluetoothProximity/wiki) on your phone to install the app over-the-air
- TestFlight (submitted for beta testing, but is not yet available)

## Supported Devices

This app has been tested on the following iPhone models:
- SE
- 5S
- 6
- 6S
- 8
- 8 Plus
- 10
- XR
- 11 Pro

There may be layout/interface issues, especially on devices with larger screens.

## Known Issues

There are some autolayout warnings when building the project. Further there are some warnings in the console when using the UI switch (GPS enable/disble) and button to share data. These appear to be Swift UI bugs and do not affect anything.

```
invalid mode 'kCFRunLoopCommonModes' provided to CFRunLoopRunSpecific - break on _CFRunLoopError_RunCalledWithInvalidMode to debug. This message will only appear once per execution.
```

```
[core] SLRemoteComposeViewController: (this may be harmless) viewServiceDidTerminateWithError: Error Domain=_UIViewServiceErrorDomain Code=1 "(null)" UserInfo={Terminated=disconnect method}
[ShareSheet] connection invalidated
```

## License

MIT License. Additional licensing information can be found in LICENSE.md.

## Disclaimer

DISTRIBUTION STATEMENT A. Approved for public release. Distribution is unlimited.
 
This material is based upon work supported by the United States Air Force under Air Force Contract No. FA8702-15-D-0001. Any opinions, findings, conclusions or recommendations expressed in this material are those of the author(s) and do not necessarily reflect the views of the United States Air Force.
 
(c) 2020 Massachusetts Institute of Technology.
 
The software/firmware is provided to you on an As-Is basis
 
Delivered to the U.S. Government with Unlimited Rights, as defined in DFARS Part 252.227-7013 or 7014 (Feb 2014). Notwithstanding any copyright notice, U.S. Government rights in this work are defined by DFARS 252.227-7013 or DFARS 252.227-7014 as detailed above. Use of this work other than as specifically authorized by the U.S. Government may violate any copyrights that exist in this work.