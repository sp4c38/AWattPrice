# **AWattPrice Xcode App**

### **Code signing**
To manage code signing certificates and provisioning profiles this project uses fastlane match.

##### For development
`bundle exec fastlane match development --readonly`

##### For Ad Hoc distribution
`bundle exec fastlane match adhoc --readonly`

##### For App Store distribution
`bundle exec fastlane match appstore --readonly`
