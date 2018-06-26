Pod::Spec.new do |s|
    s.name = 'EntropyKit'
    s.version = '0.1.0'
    s.summary = 'A framework for the Matrix spec.'
    s.source = { :git => 'https://github.com/Kodeshack/EntropyKit.git', :tag => s.version }
    s.authors = 'Kodeshack'
    s.license = 'GPL-3.0'
    s.homepage = 'https://entropy.kodeshack.com'

    s.ios.deployment_target = '11.0'
    s.osx.deployment_target = '10.13'
    s.swift_version = '4.2'

    s.source_files = 'Sources/**/*.swift'
    s.dependency 'Alamofire'
    s.dependency 'GRDB.swift'
    s.dependency 'OLMKit'
end
