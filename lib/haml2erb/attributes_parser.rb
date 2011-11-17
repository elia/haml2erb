module Haml2Erb
  class AttributesParser
    class DynamicAttributes < StandardError
    end
    
    def initialize attributes
      @attributes = attributes
      @pairs = []
    end
    attr_reader :pairs, :attributes
    
    CONTENTS    = /^, \{?(.*)\}?$/
    ROCKET      = '\=\>'
    
    SYMBOL_TEXT = '[\w_]+'
    STRING_TEXT = '[\w_-]+'
    
    SYMBOL_KEY  = /^(?:\:(#{SYMBOL_TEXT})\s*#{ROCKET}|(#{SYMBOL_TEXT}):)\s*/
    STRING_KEY  = /^(?:'(#{STRING_TEXT})'|"(#{STRING_TEXT})")\s*#{ROCKET}\s*/
    
    SYMBOL_VALUE = /^:(#{SYMBOL_TEXT})\s*/
    STRING_VALUE = /^(?:"([^"]+)"|'([^']+)')\s*/
    STRING_INTERPOLATION = /^("[^\\]*)#\{/
    
    def parse!
      rest = attributes.strip.scan(CONTENTS).flatten.first
      begin
        while rest and not(rest.empty?)
          if rest =~ SYMBOL_KEY
            key = $1 || $2
            rest.gsub! SYMBOL_KEY, ''
          elsif rest =~ STRING_KEY
            key = $1 || $2
            rest.gsub! STRING_KEY, ''
          else
            raise DynamicAttributes
          end
        
          if rest =~ STRING_VALUE
            value = $1
            raise DynamicAttributes if rest =~ STRING_INTERPOLATION
          elsif rest =~ SYMBOL_VALUE
            value = $1 || $2
          else
            raise DynamicAttributes
          end
        
          pairs << [key, value]
        end
      rescue DynamicAttributes
        @dynamic = true
        return
      end
    end
  
    def dynamic?
      @dynamic
    end
    
    def self.hash_to_html hash
      hash.each_pair.map do |key, value|
        " #{key}='#{value.gsub("'", '&#x27;')}'"
      end.join('')
    end
    
    def to_html
      if attributes.strip.empty?
        return ''
      else
        parse!
        if dynamic?
          hash = attributes.scan(CONTENTS).flatten.first
          hash.strip!
          hash.gsub! /\s*,$/, ''
          " <%= tag_options({#{hash}}, false) %>"
        else
          pairs.map do |(key, value)|
            "#{key}='#{value.gsub("'", '&#x27;')}'"
          end.join('')
        end
      end
    end
  end
end
