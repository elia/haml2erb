module Haml2Erb
  class AttributesParser
    class DynamicAttributes < StandardError
    end
    
    def initialize attributes
      @attributes = attributes
      @pairs = []
    end
    attr_reader :pairs, :attributes
    
    CONTENTS    = /^, \{(.*)\}$/
    ROCKET      = '\=\>'
    
    SYMBOL_TEXT = '[\w_]+'
    STRING_TEXT = '[\w_-]+'
    
    SYMBOL_KEY  = /^(?:\:(#{SYMBOL_TEXT})\s*#{ROCKET}|(#{SYMBOL_TEXT}):)\s*/
    STRING_KEY  = /^(?:'(#{STRING_TEXT})'|"(#{STRING_TEXT})")\s*#{ROCKET}\s*/
    
    STRING_VALUE = /^:(#{SYMBOL_TEXT})\s*/
    SYMBOL_VALUE = /^(?:"([^"]+)"|'([^']+)')\s*/
    
    def parse!
      rest = attributes.strip.scan(CONTENTS).flatten.first

      begin
        while not rest.empty?
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
          ' ' << pairs.map do |(key, value)|
            "#{key}='#{value.gsub("'", '&#x27;')}'"
          end.join(' ')
        end
      end
    end
  end
end
