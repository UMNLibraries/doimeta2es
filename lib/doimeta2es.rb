# If not sorted, these could return in an order that prevents the adapter subclasses from loading first
Dir[File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', '**', '*.rb'))].sort.each { |file| require_relative(file) }
