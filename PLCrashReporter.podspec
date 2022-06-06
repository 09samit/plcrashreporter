Pod::Spec.new do |spec|
  spec.cocoapods_version = '>= 1.10'
  spec.name        = 'AGCrashReporter'
  spec.version     = '1.10.1'
  spec.summary     = 'Reliable, open-source crash reporting for iOS, macOS and tvOS.'
  spec.description = 'PLCrashReporter is a reliable open source library that provides an in-process live crash reporting framework for use on iOS, macOS and tvOS. The library detects crashes and generates reports to help your investigation and troubleshooting with the information of application, system, process, thread, etc. as well as stack traces.'

  spec.homepage    = 'https://github.com/microsoft/plcrashreporter'
  spec.license     = { :type => 'MIT', :file => 'LICENSE.txt' }
  spec.authors     = { 'Microsoft' => 'appcentersdk@microsoft.com' }

  s.ios.deployment_target =   "10.0"
  s.tvos.deployment_target =  "10.0"
  s.osx.deployment_target =   "10.10"

  s.source       = { :git => "https://github.com/backtrace-labs/plcrashreporter.git", :tag => "#{s.version}" }

  s.source_files  = "Sources/**/*.{h,hpp,c,cpp,m,mm,s}",
                    "Dependencies/protobuf-c/protobuf-c/*.{h,c}"
  
  s.public_header_files = "Sources/include"
  s.preserve_paths = "Dependencies/**"

  s.pod_target_xcconfig = {
    "GCC_PREPROCESSOR_DEFINITIONS" => "PLCR_PRIVATE PLCF_RELEASE_BUILD"
  }
  s.libraries = "c++"
  s.requires_arc = false

  s.prefix_header_contents = '#import "PLCrashNamespace.h"'
end
