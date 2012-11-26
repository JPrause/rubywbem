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

  gem.files         = %w{
    AUTHORS
    CHANGELOG
    Gemfile
    LICENSE
    README
    Rakefile
    lib/wbem.rb
    lib/wbem/cim_constants.rb
    lib/wbem/cim_http.rb
    lib/wbem/cim_obj.rb
    lib/wbem/cim_operations.rb
    lib/wbem/cim_types.rb
    lib/wbem/cim_xml.rb
    lib/wbem/tupleparse.rb
    lib/wbem/tupletree.rb
    lib/wbem/version.rb
    ruby-wbem.spec
    rubywbem.gemspec
    test/wbemTest.rb
    testsuite/CIM_DTD_V22.dtd
    testsuite/comfychair.rb
    testsuite/runtests.sh
    testsuite/test_cim_obj.rb
    testsuite/test_cim_operations.rb
    testsuite/test_cim_xml.rb
    testsuite/test_nocasehash.rb
    testsuite/test_tupleparse.rb
    testsuite/validate.rb
  }
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "rubywbem"
  gem.require_paths = ["lib"]
  gem.version       = WBEM::VERSION

  gem.add_dependency('nokogiri', '~>1.5.0')
end
