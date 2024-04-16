Pod::Spec.new do |s|
  s.name            = 'HJTask'
  s.version         = '1.0.5'
  
  s.ios.deployment_target = '9.0'
  
  s.summary         = 'Task for NSOperation'
  s.homepage        = 'https://github.com/ObjectiveC-Lib/HJTask'
  s.source          = { :git => 'https://github.com/ObjectiveC-Lib/HJTask.git', :tag => s.version }
  s.license         = { :type => 'MIT', :file => 'LICENSE' }
  s.author          = { 'navy' => 'lzxy169@gmail.com' }
  
  s.requires_arc    = true
  s.framework       = 'UIKit', 'Foundation'
  
  s.source_files    = 'HJTask/HJTask.h'
  s.default_subspec = 'Core'
  
  s.subspec 'Core' do |core|
    core.source_files = 'HJTask/**/*.{h,m}'
  end
  
end
