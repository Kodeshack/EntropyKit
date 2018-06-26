# Comment the next line if you're not using Swift and don't want to use dynamic frameworks
use_frameworks!

podspec :path => 'EntropyKit.podspec'

# Pods for EntropyKit
pod 'SwiftFormat/CLI'

# Just to silence the warnings
pod 'OLMKit', :inhibit_warnings => true

target 'EntropyKit-iOS' do
  platform :ios, '11.0'

  target 'EntropyKit-iOSTests' do
    inherit! :search_paths
    # Pods for testing
    pod 'OHHTTPStubs/Swift'
  end

end

target 'EntropyKit-macOS' do
  platform :osx, '10.13'

  target 'EntropyKit-macOSTests' do
    inherit! :search_paths
    # Pods for testing
    pod 'OHHTTPStubs/Swift'
  end

end
