#!/usr/bin/ruby

require_relative 'AtState.rb'

class AtClassMethod < AtLambda
    def initialize(inner_ast, params=[], raw: [])
        super(inner_ast, params, raw: raw)
        @parent = nil
    end

    attr_accessor :parent

    def AtClassMethod.from(lam)
        AtClassMethod.new lam.tokens, lam.params, raw: lam.raw
    end

    def [](inst, *args)
        inst.locals.push @scope
        inst.abstract_references << self
        inst.define_local ARG_CONST, args
        @params.each_with_index { |name, i|
            inst.define_local name, args[i]
        }

        res = nil
        @tokens.each { |group|
            res = inst.evaluate_node group, args
            update_scope inst.locals.last
        }

        update_scope inst.locals.pop
        res
    end

    def update_scope(scope)
        scope.each { |key, value|
            if @parent.vars.has_key? key
                @parent.vars[key] = value
            else
                @parent.scope[key] = value
            end
        }
    end

    def inspect
        "AtClassMethod(#{@raw})"
    end
end

class AtClassInstance
    def initialize(parent, methods, vars, privates, scope)
        @methods = methods

        @methods.each { |name, value|
            next unless AtClassMethod === value
            value.scope = scope
            value.parent = self
        }

        @vars = vars
        @privates = privates
        @parent = parent
        @scope = scope
    end

    attr_accessor :vars, :methods, :parent, :scope

    def to_s
        inspect
    end

    def [](prop)
        @vars[prop] || @methods[prop]
    end

    def inspect
        @vars.delete AtLambda::ARG_CONST
        # p @vars.keys
        inner = @vars.map { |k, v|
            if v === self
                "#{k} = <recursive>"
            else
                "#{k} = #{v.inspect}"
            end
        }

        inner.concat @privates.map { |k, v|
            "Private[#{k}]"
        }

        inner = inner.join ", "

        "#{@parent.name rescue "Class"}[#{inner}]"
    end
end

# todo: template
class AtClass
    def initialize(inst, body, parent=nil, name: "anon")
        @body = body
        @body.ascend = @body.descend = false
        @inst = inst
        @name = name
    end

    attr_reader :name

    def create(*params)
        @inst.locals << {}
        privates = {}

        @inst.define_local "Private", held(true) { |inst, name|
            privates[name.raw] = true
        }

        @inst.saved = []
        @body[@inst, *params]

        scope = @inst.locals.pop
        scope.delete AtLambda::ARG_CONST

        scope.delete "Private"

        methods = {}
        vars = {}
        all = {}
        scope.each { |name, val|
            if AtState.func_like? val
                if AtLambda === val
                    val = AtClassMethod.from val
                end
                if privates[name]
                    privates[name] = val
                    methods[name] = lambda { |inst, *ignore|
                        AtError.new "Access Error", "Attempting to access private method #{name.inspect}."
                    }
                else
                    methods[name] = val
                end
            elsif privates[name]
                privates[name] = val
            else
                vars[name] = val
            end
        }

        all.merge! vars
        all.merge! methods
        all.merge! privates

        # if @name == "D2State"
            # methods["step"].scope["ip"] = 1000
        # end

        AtClassInstance.new self, methods, vars, privates, all
    end

    def [](inst, *args)
        create *args
    end

    def inspect
        "Class #{@name.inspect}"
    end
end
