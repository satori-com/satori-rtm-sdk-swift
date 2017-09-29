Pod::Spec.new do |s|
  s.name         = "SatoriRTM"
  s.version      = "0.2.0"
  s.summary      = "Swift SDK for Satori RTM."
  s.homepage     = "https://github.com/satori-com/satori-rtm-sdk-swift"
  s.license      = { :type => 'BSD' }
  s.author       = {'Satori Worldwide Inc' => 'http://satori.com'}
  s.source       = { :git => 'ssh://git@github.com/satori-com/satori-rtm-sdk-swift.git',  :tag => "#{s.version}"}
  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.12'
  s.source_files = 'Sources/*.swift'
  s.dependency 'Starscream', '3.0.0'
  s.dependency 'SwiftyBeaver', '1.4.1'
  s.requires_arc = true
  s.pod_target_xcconfig = {
    'SWIFT_INCLUDE_PATHS' => '$(PODS_ROOT)/SatoriRTM/bridging'
  }
  s.preserve_paths = 'bridging/*'
end
