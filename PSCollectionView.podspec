Pod::Spec.new do |s|
  s.name = 'PSCollectionView'
  s.version = '0.0.1'
  s.summary = 'Open Source, 100% API compatible replacement of UICollectionView for iOS4+.'
  s.homepage = 'https://github.com/moviepilot/PSCollectionView'
  s.license = {
    :type => 'MIT',
    :file => 'LICENSE'
  }
  s.author = 'Peter Steinberger', 'steipete@gmail.com'
  s.source = {
    :git => 'https://github.com/moviepilot/PSCollectionView.git',
    :commit => 'HEAD'
  }
  s.platform = :ios, '4.3'
  s.source_files = 'PSCollectionView/'
  s.public_header_files = 'PSCollectionView/'
  s.frameworks = 'UIKit', 'QuartzCore'
  s.requires_arc = true
end
