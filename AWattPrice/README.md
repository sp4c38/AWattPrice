# **AWattPrice Xcode App**

### **Code signing**
To manage code signing certificates and provisioning profiles this project uses fastlane match.

##### For development
`bundle exec fastlane match development --readonly`

##### For Ad Hoc distribution
`bundle exec fastlane match adhoc --readonly`

##### For App Store distribution
`bundle exec fastlane match appstore --readonly`

### **StoreKit**
The Pro Supporter paywall shows only products returned by StoreKit. Do not add fallback prices in code; prices must come from App Store Connect.

Current production products:
- `awattprice.pro.supporter.monthly`
- `awattprice.pro.supporter.yearly`

Future product:
- `awattprice.pro.supporter.lifetime`

When App Store Connect products change, sync `AWattPrice/AWattPrice.storekit` and keep the shared `AWattPrice` scheme pointed at that file for local StoreKit testing. The `.storekit` file should stay out of the app bundle resources.
