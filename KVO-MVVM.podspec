Pod::Spec.new do |s|
  s.name             = "KVO-MVVM"
  s.version          = "0.5.2"
  s.summary          = "KVO binding especially for ViewModel observing by View"

  s.description      = <<-DESC
                        Simply observe ViewModel changes by View layer using block-based
                        syntax over vanilla Cocoa KVO. The main idea is to observe keypaths
                        like this one - @keypath(self.viewModel.state) and not to unsubscribe.
                       DESC

  s.homepage         = "https://github.com/ML-Works/KVO-MVVM"
  s.license          = 'MIT'
  s.author           = { "Anton Bukov" => "k06aaa@gmail.com", "Andrew Podkovyrin" => "podkovyrin@gmail.com" }
  s.source           = { :git => "https://github.com/ML-Works/KVO-MVVM.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/k06a'

  s.platform     = :ios, '8.0'
  s.requires_arc = true
  s.frameworks = 'UIKit', 'CoreData'

  s.source_files = 'Pod/Classes/*.{h,m,mm}'
  s.private_header_files = 'Pod/Classes/SuperKVOPrivateImplementation.h'
end
