Pod::Spec.new do |s|

s.name            = 'CKPromise.Swift'
s.version         = '0.4'
s.summary         = 'Swift attemp to implement Promise/A+'
s.homepage        = 'https://github.com/cristik/CKPromise.Swift'
s.source          = { :git => 'https://github.com/cristik/CKPromise.Swift.git', :tag => s.version.to_s }
s.license         = { :type => 'MIT', :file => 'License.txt' }

s.authors = {
'Cristian Kocza'   => 'cristik@cristik.com',
}

s.ios.deployment_target = '8.0'
s.osx.deployment_target = '10.10'


s.source_files = 'CKPromise.Swift/*.{swift}'
end

