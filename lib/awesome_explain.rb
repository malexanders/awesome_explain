require 'awesome_print'
require 'sqlite3'
require 'active_record'
require 'kaminari'
require 'awesome_print'
require 'terminal-table'
require 'awesome_explain/version'
require 'awesome_explain/config'
require 'awesome_explain/engine'
require 'awesome_explain/utils/color'
require 'awesome_explain/renderers/mongoid'
require 'awesome_explain/kernel'
require 'awesome_explain/command_subscriber'
require 'awesome_explain/sidekiq_middleware'
require 'awesome_explain/insights'

module AwesomeExplain
  def self.clean
    AwesomeExplain::Log.delete_all
    AwesomeExplain::Explain.delete_all
    AwesomeExplain::Stacktrace.delete_all
    AwesomeExplain::Controller.delete_all
  end

  def self.configure(&block)
    raise NoBlockGivenException unless block_given?

    Config.configure(&block)
  end

  class NoBlockGivenException < RuntimeError; end
end

# TODO: Custome rake task to run migrations
AE_DB_CONFIG = {
  development: {
    adapter: 'sqlite3',
    database: "#{Rails.root || '.'}/log/ae.db",
    pool: 50,
    timeout: 5000,
  }
}.with_indifferent_access[Rails.env]

# TODO: Custome rake task to run migrations
ActiveRecord::Base.establish_connection(AE_DB_CONFIG)

connection = ActiveRecord::Base.establish_connection(AE_DB_CONFIG).connection

ActiveRecord::Schema.define do
  unless connection.table_exists?(:stacktraces)
    create_table :stacktraces do |t|
      t.column :stacktrace, :string
      t.timestamps
    end
  end

  unless connection.table_exists?(:sidekiq_workers)
    create_table :sidekiq_workers do |t|
      t.column :worker, :string
      t.column :queue, :string
      t.column :jid, :string
      t.column :params, :string
      t.timestamps
    end
  end

  unless connection.table_exists?(:controllers)
    create_table :controllers do |t|
      t.column :name, :string
      t.column :action, :string
      t.column :path, :string
      t.column :params, :string
      t.column :session_id, :string
      t.timestamps
    end
  end

  unless connection.table_exists?(:logs)
    create_table :logs do |t|
      t.column :collection, :string
      t.column :app_name, :string
      t.column :source_name, :string
      t.column :operation, :string
      t.column :collscan, :integer
      t.column :command, :string
      t.column :duration, :double
      t.column :session_id, :string
      t.column :lsid, :string

      t.column :sidekiq_args, :string
      t.column :stacktrace_id, :integer
      t.column :explain_id, :integer
      t.column :controller_id, :integer
      t.column :sidekiq_worker_id, :integer
      t.timestamps
    end
  end

  unless connection.table_exists?(:explains)
    create_table :explains do |t|
      t.column :collection, :string
      t.column :source_name, :string
      t.column :command, :string
      t.column :collscan, :integer
      t.column :winning_plan, :string
      t.column :winning_plan_raw, :string
      t.column :used_indexes, :string
      t.column :duration, :double
      t.column :documents_returned, :integer
      t.column :documents_examined, :integer
      t.column :keys_examined, :integer
      t.column :rejected_plans, :integer
      t.column :session_id, :string
      t.column :lsid, :string
      t.column :stacktrace_id, :integer
      t.column :controller_id, :integer
      t.timestamps
    end
  end

  unless connection.table_exists?(:transactions)
    create_table :transactions do |t|
      t.column :params, :string
      t.column :format, :string
      t.column :method, :string
      t.column :ip, :string
      t.column :stash, :string
      t.column :status, :string
      t.column :view_runtime, :string

      t.column :controller_id, :integer
      t.timestamps
    end
  end
end

# ActiveSupport::Notifications.subscribe 'start_processing.action_controller' do |*args|
#   data = args.extract_options!
#   unless data[:controller] =~ /AwesomeExplain/ || data[:controller] =~ /ErrorsController/ || data[:path] =~ /awesome_explain/
#     Thread.current[:ae_controller_data] = data
#   end
#   Thread.current[:ae_session_id] = SecureRandom.uuid
# end

# ActiveSupport::Notifications.subscribe 'process_action.action_controller' do |*args|
#   Thread.current[:ae_session_id] = nil
# end
