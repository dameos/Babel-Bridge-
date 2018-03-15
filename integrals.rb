
require "babel_bridge"


class TuringParser < BabelBridge::Parser

"whole_words"
ignore_whitespace

def store
  @store||=[]
end

# the stack consists of an array of hashs
# Each entry in the stack is a call-frame with a hash of local variable names
def stack; @stack ||= [{}]; end

def current_stack_frame; stack[-1]; end
def globals; stack[0]; end


rule :statements, many(:statement,";"), match?(";") do
  def evaluate
    ret = nil
    statement.each do |s|
      ret = s.evaluate
    end
    ret
  end
end

rule :statement, :function_definition

rule :function_definition, "def", :identifier, :parameter_list?, "do", :statements, "end" do
  def evaluate
    stack_frame = parser.current_stack_frame
    stack_frame[identifier.to_sym] = self
    1 # return true
  end

  def parameter_names; @parameter_names||=parameter_list ? parameter_list.parameter_names : []; end

  def evaluate_function(params)
    params ||= []
    locals = {}
    raise "wrong number of parameters. #{identifier} expects #{parameter_names.length} but got #{params.length}" unless params.length == parameter_names.length
    parameter_names.each_with_index do |name,index|
      locals[name] = params[index]
    end
    parser.stack << locals
    statements.evaluate.tap {parser.stack.pop}
  end
end

rule :parameter_list, "(", many(:identifier, ","), ")" do
  def parameter_names
    @parameter_names ||= identifier.collect{|a|a.to_sym}
  end
end

rule :statement, "if", :statement, "then", :statements, :else_clause?, "end" do
  def evaluate
    if statement.evaluate
      statements.evaluate
    elsif else_clause
      else_clause.evaluate
    end
  end
end
rule :else_clause, "else", :statements

rule :statement, "switch", :operand, :caset, "default", :statements, "end" do
  def evaluate
     if operand.to_s.to_i == caset.operand.to_s.to_i
        caset.evaluate
    else
      statements.evaluate
    end 
  end 
end

rule :caset, "case", :operand, ":", :statements, :caset? do
 def evaluate 
    statements.evaluate
 end 
end

rule :statement, "while", :statement, "do", :statements, "end" do
  def evaluate
    ret = nil
    while statement.evaluate
      ret = statements.evaluate
    end
    ret
  end
end

rule :statement, "derivate", :statement do
   def evaluate
      0
   end
end

rule :statement, ":quit" do
  def evaluate 
      exit!   
  end
end 

binary_operators_rule :statement, :operand, [[:/, :*], [:+, :-], [:<, :<=, :>, :>=, :==]] do
  def evaluate
    ret = left.evaluate.send operator, right.evaluate
    case operator
    when :<, :<=, :>, :>=, :== then ret ? 1 : nil
    else ret
    end
  end
end

rule :operand, "(", :statement, ")"

rule :operand, "[", :statement, "]", "=", :statement do
  def evaluate
    parser.store[statement[0].evaluate] = statement[1].evaluate
  end
end

rule :operand, "[", :statement, "]" do
  def evaluate
    parser.store[statement.evaluate]
  end
end

rule :operand, "nil" do
  def evaluate
    nil
  end
end

rule :operand, :identifier, "=", :statement do
  def evaluate
    stack_frame = parser.current_stack_frame
    stack_frame[identifier.to_sym] = statement.evaluate
  end
end

rule :operand, :identifier, :parameters? do
  def evaluate
    globals = parser.globals
    stack_frame = parser.current_stack_frame
    name = identifier.to_sym
    raise "undefined variable: #{name.inspect}" unless globals.has_key?(name) || stack_frame.has_key?(name)
    case value = stack_frame.has_key?(name) ? stack_frame[name] : globals[name]
    when BabelBridge::Node then value.evaluate_function(parameters.evaluate)
    else value
    end
  end
end

rule :parameters, "(", many(:statement,","), ")" do
  def evaluate
    statement.collect {|s|s.evaluate}
  end
end


rule :identifier, /[_a-zA-Z][_a-zA-Z0-9]*/

rule :operand, /[-]?[0-9]+/ do
  def evaluate
    to_s.to_i
  end
end
w


files=false
parser = TuringParser.new
ARGV.each do |file|
  puts TuringParser.new.parse(File.read(file)).evaluate
  files = true
end

if !files 
  BabelBridge::Shell.new(TuringParser.new).start
end