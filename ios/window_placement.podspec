Pod::Spec.new do |s|
  s.name             = 'window_placement'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin capable of telling where an app is displayed on a mobile device display'
  s.description      = <<-DESC
A Flutter plugin capable of telling where an app is displayed on a mobile device display
                       DESC
  s.homepage         = 'https://github.com/JanMichaelPeter/window_placement'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'JanMichaelPeter'
  s.source           = { :path => '.' }
  s.source_files = 'window_placement/Sources/window_placement/**/*.swift'
  s.resource_bundles = {'window_placement_privacy' => ['window_placement/Sources/window_placement/PrivacyInfo.xcprivacy']}
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
