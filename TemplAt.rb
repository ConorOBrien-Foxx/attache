#!/usr/bin/ruby

require_relative 'AtState.rb'
require 'nokogiri'

# <attache>...</attache>
#    raw attache code; final result stringified

# compiles a templat document
def templat(str)
    inst = AtState.new <<EOT
    Needs[$html]
    Needs[$http]
    load := {
        el .= _1
        content .= _2
        
        document .= el.document
        
        append .= {
            HTMLAddNext[el, ToHTML[_, document]]
        }   
        delete .= {
            HTMLRemove => __
        }
        update .= {
            HTMLReplace[el, ToHTML[_, document]]
        }
        html .= HTMLSelect[document, "html"]
        head .= HTMLSelect[document, "head"]
        body .= HTMLSelect[document, "body"]
        value .= content |> EvalHere
    }
EOT
    inst.run
    load = lambda { |*args|
        inst.variables["load"][inst, *args]
    }
    
    parsed = Nokogiri::HTML(str)
    
    parsed.css("attache").each { |el|
        content = el.children.map(&:text).join
        result = load[el, content].to_s
        # text = Nokogiri::XML::Text.new result, el.document
        # el.replace text
    }
    
    parsed
end

