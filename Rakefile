# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/switchtower.rake, and they will automatically be available to Rake.

require(File.join(File.dirname(__FILE__), 'config', 'boot'))
require 'rake/dsl_definition'
require 'rake'
require 'rake/testtask'

begin
  require 'rdoc/task'
rescue LoadError
  # RDoc is not available
end

require 'tasks/rails'
