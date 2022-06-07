Pod::Spec.new do |s|
  s.name        = 'AGCrashReporter'
  s.version     = '1.10.1'
  s.summary     = 'Reliable, open-source crash reporting for iOS, macOS and tvOS.'
  s.description = 'PLCrashReporter is a reliable open source library that provides an in-process live crash reporting framework for use on iOS, macOS and tvOS. The library detects crashes and generates reports to help your investigation and troubleshooting with the information of application, system, process, thread, etc. as well as stack traces.'

  s.homepage    = 'https://github.com/09samit/plcrashreporter'
  s.license     = { :type => 'MIT', :file => 'LICENSE.txt' }
  s.authors     = { 'Amit' => '09s.amitgarg@gmail.com' }

  s.ios.deployment_target =   "9.0"
  s.tvos.deployment_target =  "9.0"
  s.osx.deployment_target =   "10.10"

  s.source       = { :git => "https://github.com/09samit/plcrashreporter.git", :tag => "#{s.version}" }

  s.source_files  = "Sources/**/*.{h,hpp,c,cpp,m,mm,s}",
                    "Dependencies/protobuf-c/protobuf-c/*.{h,c}"

  s.pod_target_xcconfig = {
    "GCC_PREPROCESSOR_DEFINITIONS" => "PLCR_PRIVATE PLCF_RELEASE_BUILD"
  }
end
