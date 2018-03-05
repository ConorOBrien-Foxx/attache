#!/usr/bin/ruby

load 'boilerplates.rb'
title = "AtState.rb"
input = File.read title

require_relative 'AtState.rb'

$inst = AtState.new "Needs[$visuals]"
$inst.run

def highlight_html(str)
    $inst.variables["highlight_html"][$inst, str]
end



$AFTER_COMMENT = /(?<=#).+/
$COMMENT_GROUP = /#<<[\s\S]+?#>>\s+.+?$/
$SIGNATURE_PARSE = /"(\w+)" => (\w+(?:\(.+?\))?) \{ \|(.+?)\|\s*$/
$DATA_LINE = /@(\w+)\s?(.+)/

groups = input.scan($COMMENT_GROUP)

$final = {}

$PUSH_COLLECT = {
    "type" => [:types, 2],
    "param" => [:params, 2],
    "option" => [:options, 2],
}
$APPEND = [
    "example",
    "paramtype",
]
def text_from_signature(sig)
    if sig.index "vector"
        after = case sig
            when /monad/
                " monadically"
            when /RIGHT/
                " dyadically on the right"
            when /LEFT/
                " dyadically on the left"
            when /dyad/
                " dyadically"
            else
                ""
        end
        "<p><em>Vectorizes#{after}.</em></p>"
    else
        ""
    end
end

groups.each { |group|
    head, *body, tail, signature = group.lines
    
    body.map! { |e|
        e.scan($AFTER_COMMENT).first.strip
    }
    
    info = Hash.new("")
    $PUSH_COLLECT.values.each { |k| info[k[0]] = {} }
    $APPEND.each { |k| info[k.to_sym] = [] }
    
    body.each { |line|
        data = line.scan($DATA_LINE)
        if data.empty?
            info[:description] += line + " "
        else
            key, value = data.first
            if $PUSH_COLLECT.has_key? key
                source, arity = $PUSH_COLLECT[key]
                name, *other = value.split(/\b\s*/, arity)
                info[source][name] = other
            elsif $APPEND.include? key
                info[key.to_sym] << value
            else
                info[key.to_sym] = value
            end
        end
    }
    
    name, type, args = signature.scan($SIGNATURE_PARSE).first
    args = args.split(/,\s*/)
    
    args.shift # remove inst
    
    $final[name] = {
        info: info,
        type: type,
        args: args,
    }
}

result = ""
toc = ""
$final.sort.each { |k, v|
    result += "<div class=\"function\">"
    args_types = {}
    v[:args].map! { |e|
        # e = e[0]
        name, default = e.split("=")
        decoration = name.scan(/\W+/).first
        name.gsub!(/\W/, "")
        
        pref, * = v[:info][:types][name]
        
        disp_name = name
        
        disp_name = "..." + disp_name if decoration == "*"
        disp_name = "**" + disp_name if decoration == "**"
        
        head = unless pref.nil?
            BOILERPLATES[:argument] % {
                type: pref,
                name: disp_name,
            }
        else
            disp_name
        end
        
        unless default.nil?
            if v[:info][:optional][name]
                head += "?"
            else
                head += "=" + default
            end
        end
        
        args_types[name] = head
    }
    
    if v[:info][:return].empty?
        STDERR.puts "Warning: no return type given for #{k.inspect}"
    end
    
    result += BOILERPLATES[:header] % {
        return_type:    v[:info][:return],
        name:           k,
        args:           v[:args].join(", "),
        genre:          v[:info][:genre],
    }
    
    result += text_from_signature v[:type]
    
    result += v[:info][:description].gsub(/\s+/, " ")
    
    unless v[:info][:params].empty? && v[:info][:paramtype].empty?
        result += "<h3>Arguments</h3>" 
    end
    
    v[:info][:params].each { |var, (val, *)|
        result += BOILERPLATES[:param] % {
            name: args_types[var],
            description: val,
        }
    }
    
    v[:info][:paramtype].each { |line|
        type, name, desc = line.split(" ", 3)
        result += BOILERPLATES[:param] % {
            name: BOILERPLATES[:argument] % {
                name: name,
                type: type,
            },
            description: desc,
        }
    }
    
    unless v[:info][:options].empty?
        result += "<h3>Options</h3>"
        result += v[:info][:options].map { |name, (description, *)|
            BOILERPLATES[:option] % {
                name: name,
                description: description,
            }
        }.join("\n")
    end
    
    unless v[:info][:example].empty?
        result += BOILERPLATES[:example] % {
            code: highlight_html(v[:info][:example].join("\n"))
        }
    end
    
    result += "</div>"
}

File.write "docs/index.html", BOILERPLATES[:html] % {
    title: title,
    body: result
}






