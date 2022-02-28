# frozen_string_literal: true

require 'yaml'

class CommandArgs
  attr_accessor :deployments

  def initialize
    path = Env.fetch('SECRETS_FILE_PATH', './secret.deploy.values.yml') # Either symlink or pass the env var.
    config = YAML.load_file(path)
    defaults = config['_global_defaults'] || {}
    config.each_key do |key|
      config.delete(key) if key.match?(/^_/)
    end

    # Filter to this application (sometimes we share apps in a single secret.deploy.values.yml file)
    app_key = ENV.fetch('ECS_DEPLOY_APP_KEY', nil)
    config = config[app] unless app_key.nil?

    raise "Set first param as group of environments to deploy/build: #{config.keys}" unless ARGV[0]

    self.deployments = config[ARGV[0]]

    raise "Set a valid group: #{ARGV[0]} must be in #{config.keys.join(', ')}" if deployments.nil?

    # Merge in defaults
    deployments.each_index do |i|
      deployments[i] = defaults.merge(deployments[i])
    end
  end

  def self.cluster
    ENV.fetch('CLUSTER_NAME', '')
  end

  def cluster
    CommandArgs.cluster
  end
end
