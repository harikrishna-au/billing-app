# Pine Labs Printing Follow-Up Email

**Subject:** Re: WATERSPORTS SIMPLE INDIA PRIVATE LIMITED-PI-7925 - Printing still not working

Hi Laxmi / Chetan / Plutus Integration Team,

We have updated and tested the MIT APK as per your instructions.

The following has been completed from our side:

- Added manifest package visibility:
  `<package android:name="com.pinelabs.masterapp" />`
- Using UAT Application ID: `0269e0a955c4370a9c04c78fb111bd4`
- App Package Name: `com.mit`
- Device Serial Number: `2842079646`
- POS ID shared/configured: `1014596`
- Device Model: `A910S`
- We installed the updated Home application shared through WhatsApp.
- We cleared Home App data, activated, and settled the device to download the latest configuration.

The app is able to run on the terminal, but ticket/receipt printing is still not working through the Pine Labs MasterApp print flow.

Could you please verify the below from your side?

1. Whether serial number `2842079646` is correctly mapped in UAT against Application ID `0269e0a955c4370a9c04c78fb111bd4`.
2. Whether print service / print API is enabled for our app package `com.mit`.
3. Whether `MethodId: 1002` print requests are supported/enabled for this mapped terminal.
4. Whether the latest Home/MasterApp installed on this device supports app-to-app print requests.
5. Please share the expected print request JSON format for this device, or confirm if the sample repo format is enough.

Current print flow from our app:

- Bind to `com.pinelabs.masterapp`
- Send print request through `com.pinelabs.masterapp.HYBRID_REQUEST`
- MethodId used for print: `1002`
- Package name sent: `com.mit`

Please help us debug this from Pine Labs logs/server side, or schedule a quick call so we can test live on the terminal.

Regards,  
Hari Krishna  
9030920129
