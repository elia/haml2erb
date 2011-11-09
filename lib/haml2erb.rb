require 'haml2erb/version'
require 'haml2erb/engine'

module Haml2Erb
  def self.convert template, options = {}
    Engine.new(template, {:format => :html5}.merge(options)).to_erb
  end
end
