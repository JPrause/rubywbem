# -*- encoding: utf-8 -*-
require File.expand_path('../lib/wbem/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Scott Seago", "Tim Potter"]
  gem.email         = ["sseago@redhat.com", "tpot@hp.com"]
  gem.description   = %q{RubyWBEM is a pure-Ruby library for performing CIM operations over
HTTP using the WBEM management protocol. RubyWBEM originated as a
direct port of pyWbem (http://pywbem.sourceforge.net).}
  gem.summary       = %q{RubyWBEM is a pure-Ruby library for performing operations using the WBEM management protocol}
  gem.homepage      = "http://rubyforge.org/projects/rubywbem"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "rubywbem"
  gem.require_paths = ["lib"]
  gem.version       = WBEM::VERSION

  gem.add_dependency('nokogiri', '~>1.5.0')
end
