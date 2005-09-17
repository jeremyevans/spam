# Load the Rails framework and configure your application.
# You can include your own configuration at the end of this file.
#
# Be sure to restart your webserver when you modify this file.

# The path to the root directory of your application.
RAILS_ROOT = File.join(File.dirname(__FILE__), '..')

# The environment your application is currently running.  Don't set
# this here; put it in your webserver's configuration as the RAILS_ENV
# environment variable instead.
#
# See config/environments/*.rb for environment-specific configuration.
RAILS_ENV  = ENV['RAILS_ENV'] || 'development'


# Load the Rails framework.  Mock classes for testing come first.
ADDITIONAL_LOAD_PATHS = ["#{RAILS_ROOT}/test/mocks/#{RAILS_ENV}"]

# Then model subdirectories.
ADDITIONAL_LOAD_PATHS.concat(Dir["#{RAILS_ROOT}/app/models/[_a-z]*"])
ADDITIONAL_LOAD_PATHS.concat(Dir["#{RAILS_ROOT}/components/[_a-z]*"])

# Followed by the standard includes.
ADDITIONAL_LOAD_PATHS.concat %w(
  app 
  app/models 
  app/controllers 
  app/helpers 
  app/apis 
  components 
  config 
  lib 
  vendor 
  vendor/rails/railties
  vendor/rails/railties/lib
  vendor/rails/actionpack/lib
  vendor/rails/activesupport/lib
  vendor/rails/activerecord/lib
  vendor/rails/actionmailer/lib
  vendor/rails/actionwebservice/lib
).map { |dir| "#{RAILS_ROOT}/#{dir}" }.select { |dir| File.directory?(dir) }

# Prepend to $LOAD_PATH
ADDITIONAL_LOAD_PATHS.reverse.each { |dir| $:.unshift(dir) if File.directory?(dir) }

# Require Rails libraries.
require 'rubygems' unless File.directory?("#{RAILS_ROOT}/vendor/rails")

require 'active_support'
require 'active_record'
require 'action_controller'
require 'action_mailer'
require 'action_web_service'

# Environment-specific configuration.
require_dependency "environments/#{RAILS_ENV}"
ActiveRecord::Base.configurations = File.open("#{RAILS_ROOT}/config/database.yml") { |f| YAML::load(f) }
ActiveRecord::Base.establish_connection


# Configure defaults if the included environment did not.
begin
  RAILS_DEFAULT_LOGGER = Logger.new("#{RAILS_ROOT}/log/#{RAILS_ENV}.log")
  RAILS_DEFAULT_LOGGER.level = (RAILS_ENV == 'production' ? Logger::INFO : Logger::DEBUG)
rescue StandardError
  RAILS_DEFAULT_LOGGER = Logger.new(STDERR)
  RAILS_DEFAULT_LOGGER.level = Logger::WARN
  RAILS_DEFAULT_LOGGER.warn(
    "Rails Error: Unable to access log file. Please ensure that log/#{RAILS_ENV}.log exists and is chmod 0666. " +
    "The log level has been raised to WARN and the output directed to STDERR until the problem is fixed."
  )
end

[ActiveRecord, ActionController, ActionMailer].each { |mod| mod::Base.logger ||= RAILS_DEFAULT_LOGGER }
[ActionController, ActionMailer].each { |mod| mod::Base.template_root ||= "#{RAILS_ROOT}/app/views/" }

# Set up routes.
ActionController::Routing::Routes.reload

Controllers = Dependencies::LoadingModule.root(
  File.join(RAILS_ROOT, 'app', 'controllers'),
  File.join(RAILS_ROOT, 'components')
)

# Include your app's configuration here:
class Float
  def to_money
    "$%.02f" % self
  end
end

class String
  def to_money
    self.to_f.to_money
  end
end

class ActiveRecord::Base
  @scaffold_fields = nil
  def self.scaffold_fields
    @scaffold_fields ||= content_columns.collect { |c| c.name }
  end

  @scaffold_select_order = nil
  def self.scaffold_select_order
    @scaffold_select_order
  end
  
  def self.reflection_merge(reflection, from, to)
    foreign_key = reflection.options[:foreign_key] || table_name.classify.foreign_key
    sql = case reflection.macro
      when :has_one, :has_many
        "UPDATE #{reflection.klass.table_name} SET #{foreign_key} = #{to} WHERE #{foreign_key} = #{from}\n"
      when :has_and_belongs_to_many
        join_table = reflection.options[:join_table] || ( table_name < reflection.klass.table_name ? '#{table_name}_#{reflection.klass.table_name}' : '#{reflection.klass.table_name}_#{table_name}')
        "UPDATE #{join_table} SET #{foreign_key} = #{to} WHERE #{foreign_key} = #{from}\n"
    end
    connection.update(sql)
  end

  def self.merge_records(from, to)
    reflect_on_all_associations.each{|reflection| reflection_merge(reflection, from, to)}
    destroy(from)
  end

  def scaffold_name
    self[:name] || id
  end
  
  def merge_into(record)
    raise ActiveRecordError if record.class != self.class
    self.class.reflect_on_all_associations.each{|reflection| self.class.reflection_merge(reflection, id, record.id)}
    destroy
    record.reload
  end 
end

require 'action_view'
module ActionView::Helpers
  module ActiveRecordHelper
    def input(record_name, method, options = {})
      InstanceTag.new(record_name, method, self).to_tag(options)
    end
  
    def all_input_tags(record, record_name, options)
      input_block = options[:input_block] || default_input_block
      rows = record.class.scaffold_fields.collect do |field|
        reflection = record.class.reflect_on_association(field.to_sym)
        if reflection
          input_block.call(record_name, reflection) 
        else
          input_block.call(record_name, record.column_for_attribute(field))
        end
      end
      "<table class='formtable'><tbody>#{rows.join}</tbody></table><br />"
    end
  
    def default_input_block
      Proc.new do |record, column| 
        if column.class.name =~ /Reflection/
          if column.macro == :belongs_to
            "<tr><td>#{column.name.to_s.capitalize.gsub('_',' ')}:</td><td>#{input(record, column.name)}</td></tr>\n"
          end
        else
          "<tr><td>#{column.human_name}:</td><td>#{input(record, column.name)}</td></tr>\n"
        end  
      end
    end
  end

  class InstanceTag #:nodoc:
    alias_method :to_tag_old, :to_tag
    def to_tag(options = {})
      options[:include_blank] = true if options[:include_blank].nil? and [:select, :boolean, :date, :datetime].include?(column_type)
      case column_type
        when :text
          return @method_name.downcase =~ /description/ ? to_text_area_tag(options) : to_input_field_tag('text', options)
        when :select
          return to_association_select_tag(options)
      end
      to_tag_old(options)
    end
  
    def to_boolean_select_tag(options = {})
      include_blank = true if options[:include_blank]
      options = options.stringify_keys
      add_default_name_and_id(options)
      tag_text = "<select"
      tag_text << tag_options(options)
      tag_text << "><option></option" if include_blank
      tag_text << "><option value=\"false\""
      tag_text << " selected='selected'" if value == false
      tag_text << ">False</option><option value=\"true\""
      tag_text << " selected='selected'" if value
      tag_text << ">True</option></select>"
    end
  
    def to_text_area_tag(options = {})
      options = DEFAULT_TEXT_AREA_OPTIONS.merge(options.stringify_keys)
      add_default_name_and_id(options)
      content_tag("textarea", html_escape(value), options)
    end
  
    def column_type
      object.attributes.include?(@method_name) ? object.send(:column_for_attribute, @method_name).type : :select
    end
      
    def to_association_select_tag(options)
      reflection = object.class.reflect_on_association @method_name.to_sym
      @method_name = reflection.options[:foreign_key] || reflection.klass.table_name.classify.foreign_key
      to_collection_select_tag(reflection.klass.find(:all, :order => reflection.klass.scaffold_select_order, :conditions=>reflection.options[:conditions]), :id, :scaffold_name, options, {})
    end
  end
end

class ActionController::Base
  @@scaffold_template_dir = "#{RAILS_ROOT}/lib/scaffolds"
  cattr_accessor :scaffold_template_dir
  
  private
  def scaffold_path(template_name)
    File.join(@@scaffold_template_dir, template_name+'.rhtml')
  end
  
  def render_merge_scaffold(action = "merge")
    if template_exists?("#{self.class.controller_path}/#{action}")
      render_action(action)
    else
      add_instance_variables_to_assigns
      @template.instance_variable_set("@content_for_layout", @template.render_file(scaffold_path(action), false))
      if !active_layout.nil?
        render_file(active_layout, nil, true)
      else
        render_file(scaffold_path("layout"))
      end
    end
  end
end

module ActionController::Scaffolding::ClassMethods
  def scaffold(model_id, options = {})
    options.assert_valid_keys(:class_name, :suffix)
  
    singular_name = model_id.id2name
    class_name    = options[:class_name] || Inflector.camelize(singular_name)
    plural_name   = Inflector.pluralize(singular_name)
    suffix        = options[:suffix] ? "_#{singular_name}" : ""
  
    unless options[:suffix]
      module_eval <<-"end_eval", __FILE__, __LINE__
        def index
          list
        end
      end_eval
    end
    
    module_eval <<-"end_eval", __FILE__, __LINE__
      def list#{suffix}
        # @#{singular_name}_pages, @#{plural_name} = paginate :#{singular_name}, :per_page => 10
        @#{plural_name} = #{class_name}.find(:all, :order=>#{class_name}.scaffold_select_order)
        render#{suffix}_scaffold "list#{suffix}"
      end
  
      def show#{suffix}
        @#{singular_name} = #{class_name}.find(@params["id"])
        render#{suffix}_scaffold
      end
      
      def new#{suffix}
        @#{singular_name} = #{class_name}.new
        render#{suffix}_scaffold
      end
      
      def create#{suffix}
        @#{singular_name} = #{class_name}.new(@params["#{singular_name}"])
        if @#{singular_name}.save
          flash["notice"] = "#{class_name} was successfully created"
          redirect_to :action => "show#{suffix}", :id => @#{singular_name}.id
        else
          render#{suffix}_scaffold('new')
        end
      end
      
      def edit#{suffix}
        @#{singular_name} = #{class_name}.find(@params["id"])
        render#{suffix}_scaffold
      end
      
      def update#{suffix}
        @#{singular_name} = #{class_name}.find(@params["#{singular_name}"]["id"])
        @#{singular_name}.attributes = @params["#{singular_name}"]
  
        if @#{singular_name}.save
          flash["notice"] = "#{class_name} was successfully updated"
          redirect_to :action => "show#{suffix}", :id => @#{singular_name}.id.to_s
        else
          render#{suffix}_scaffold('edit')
        end
      end
      
      private
        def render#{suffix}_scaffold(action=nil)
          action ||= caller_method_name(caller)
          # logger.info ("testing template:" + "\#{self.class.controller_path}/\#{action}") if logger
          
          if template_exists?("\#{self.class.controller_path}/\#{action}")
            render_action(action)
          else
            @scaffold_class = #{class_name}
            @scaffold_singular_name, @scaffold_plural_name = "#{singular_name}", "#{plural_name}"
            @scaffold_suffix = "#{suffix}"
            add_instance_variables_to_assigns
  
            @template.instance_variable_set("@content_for_layout", @template.render_file(scaffold_path(action.sub(/#{suffix}$/, "")), false))
  
            if !active_layout.nil?
              render_file(active_layout, nil, true)
            else
              render_file(scaffold_path("layout"))
            end
          end
        end
        
        def caller_method_name(caller)
          caller.first.scan(/`(.*)'/).first.first # ' ruby-mode
        end
    end_eval
  end

  def scaffold_merge(klass, suffix=false)
    suffix = suffix ? "_#{Inflector.underscore(klass.name)}" : ''
    class_eval <<-"end_eval", __FILE__, __LINE__
      def merge#{suffix}
        @records = #{klass.name}.find(:all, :order=>"#{klass.scaffold_select_order}")
        @singular_name = '#{Inflector.underscore(klass.name).gsub('_',' ')}'
        @many_name = '#{Inflector.underscore(Inflector.pluralize(klass.name)).capitalize.gsub('_',' ')}'
        @scaffold_suffix = '#{suffix}'
        render_merge_scaffold
      end
      
      def merge_update#{suffix}
        #{klass.name}.merge_records(params[:from], params[:to])
        redirect_to :action=>'merge#{suffix}'
      end
    end_eval
  end
end
