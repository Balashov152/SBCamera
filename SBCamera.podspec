#
# Be sure to run `pod lib lint SBCamera.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SBCamera'
  s.version          = '0.3.0'
  s.summary          = 'Swift camera SBCamera. Will include photo from library, cropper, and simple filter.'
  s.swift_versions   = '5.0'
# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
                "Swift camera SBCamera. Will include photo from library, cropper, and simple filter."
                       DESC

  s.homepage         = 'https://github.com/Balashov152/SBCamera'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Balashov152' => 'balashov.152@gmail.com' }
  s.source           = { :git => 'https://github.com/Balashov152/SBCamera.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'
  s.pod_target_xcconfig = { "SWIFT_VERSION" => "5.0" }

  s.source_files = 'SBCamera/Classes/**/*'
  
  # s.resource_bundles = {
  #   'SBCamera' => ['SBCamera/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
   s.frameworks = 'UIKit', 'Photos'
   s.dependency 'SwiftPermissionManager', '~> 0.2'
   s.dependency 'RSKImageCropper', '~> 2.2'
   
end
