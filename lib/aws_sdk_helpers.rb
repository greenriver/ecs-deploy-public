require 'aws-sdk-iam'
require 'aws-sdk-elasticloadbalancingv2'
require 'aws-sdk-ecr'
require 'aws-sdk-ecs'
require 'aws-sdk-secretsmanager'
require 'aws-sdk-autoscaling'
require 'aws-sdk-ec2'
require 'aws-sdk-cloudwatchevents'
require 'aws-sdk-cloudwatch'
require 'aws-sdk-cloudwatchlogs'
require 'aws-sdk-ssm'
require 'active_support'

module AwsSdkHelpers
  extend ActiveSupport::Concern

  module ClientMethods
    define_singleton_method(:iam) { Aws::IAM::Client.new }
    define_singleton_method(:elbv2) { Aws::ElasticLoadBalancingV2::Client.new }
    define_singleton_method(:ecr) { Aws::ECR::Client.new }
    define_singleton_method(:ecs) { Aws::ECS::Client.new }
    define_singleton_method(:secretsmanager) { Aws::SecretsManager::Client.new }
    define_singleton_method(:autoscaling) { Aws::AutoScaling::Client.new }
    define_singleton_method(:ec2) { Aws::EC2::Client.new }
    define_singleton_method(:cloudwatchevents) { Aws::CloudWatchEvents::Client.new }
    define_singleton_method(:cw) { Aws::CloudWatch::Client.new }
    define_singleton_method(:cwl) { Aws::CloudWatchLogs::Client.new }
    define_singleton_method(:ssm) { Aws::SSM::Client.new }

    define_method(:iam)              { AwsSdkHelpers::ClientMethods.iam }
    define_method(:elbv2)            { AwsSdkHelpers::ClientMethods.elbv2 }
    define_method(:ecr)              { AwsSdkHelpers::ClientMethods.ecr }
    define_method(:ecs)              { AwsSdkHelpers::ClientMethods.ecs }
    define_method(:secretsmanager)   { AwsSdkHelpers::ClientMethods.secretsmanager }
    define_method(:autoscaling)      { AwsSdkHelpers::ClientMethods.autoscaling }
    define_method(:ec2)              { AwsSdkHelpers::ClientMethods.ec2 }
    define_method(:cloudwatchevents) { AwsSdkHelpers::ClientMethods.cloudwatchevents }
    define_method(:cw)               { AwsSdkHelpers::ClientMethods.cw }
    define_method(:cwl)              { AwsSdkHelpers::ClientMethods.cwl }
    define_method(:ssm)              { AwsSdkHelpers::ClientMethods.ssm }
  end

  module Helpers
    include AwsSdkHelpers::ClientMethods

    def self.cluster_name
      ENV.fetch('CLUSTER_NAME', 'openpath')
    end

    def _cluster_name
      AwsSdkHelpers::Helpers.cluster_name
    end

    def self.capacity_providers(cluster)
      r = {}
      capacity_provider_names = AwsSdkHelpers::ClientMethods.ecs.describe_clusters(clusters: [cluster]).clusters.first.capacity_providers
      AwsSdkHelpers::ClientMethods.ecs.describe_capacity_providers(capacity_providers: capacity_provider_names).capacity_providers.each do |capacity_provider|
        asg_name = capacity_provider.auto_scaling_group_provider.auto_scaling_group_arn.split('/').last
        asg = AwsSdkHelpers::ClientMethods.autoscaling.describe_auto_scaling_groups(auto_scaling_group_names: [asg_name]).auto_scaling_groups.first

        launch_template_id = asg.mixed_instances_policy.launch_template.launch_template_specification.launch_template_id
        launch_template_versions = AwsSdkHelpers::ClientMethods.ec2.describe_launch_template_versions(launch_template_id: launch_template_id)

        ami_id = launch_template_versions.launch_template_versions[0].launch_template_data.image_id

        r[capacity_provider.name] = {
          name: capacity_provider.name,
          ami_id: ami_id,
        }
      end
      r
    end

    def _capacity_providers(cluster = nil)
      cluster ||= _cluster_name
      @capacity_providers ||= AwsSdkHelpers::Helpers.capacity_providers(cluster)
    end

    def self.default_placement_constraints(ami_id:, cluster_name:, capacity_provider_name:)
      # Confirm that there is at least one instance w/the provided AMI ID.
      payload = {
        filters: [
          {
            name: 'tag:ecs',
            values: ['true'],
          },
          {
            name: 'tag:Cluster',
            values: [cluster_name],
          },
          {
            name: 'tag:capacity-provider.name',
            values: [capacity_provider_name],
          },
          {
            name: 'image-id',
            values: [ami_id],
          },
        ],
      }
      matching_instances = ClientMethods.ec2.describe_instances(payload)

      return unless matching_instances.reservations.count.positive? && !ami_id.empty?

      [
        {
          expression: "attribute:ecs.ami-id == #{ami_id}",
          type: 'memberOf',
        },
      ]
    end

    def _default_placement_constraints(capacity_provider_name: nil, ami_id: nil)
      capacity_provider_name ||= _capacity_providers.keys.first
      ami_id                 ||= _capacity_providers[capacity_provider_name][:ami_id]

      AwsSdkHelpers::Helpers.default_placement_constraints(
        {
          ami_id: ami_id,
          cluster_name: _cluster_name,
          capacity_provider_name: capacity_provider_name,
        },
      )
    end

    def self.get_capacity_provider_name(namespace = '', which = 'Spot')
      default_path = "/Default/CapacityProviders/#{which}"
      namespaced_path = "/#{namespace}/CapacityProviders/#{which}"

      params = AwsSdkHelpers::ClientMethods.ssm.get_parameters(
        {
          names: [
            default_path,
            namespaced_path,
          ],
        },
      )

      if params.parameters.count == 2
        params.parameters.find { |p| p[:name] == namespaced_path }[:value]
      elsif params.parameters.count == 1
        params.parameters[0][:value]
      else
        raise "No capacity provider name found: #{which}"
      end
    end

    def _spot_capacity_provider_name
      target_group_name ||= self.respond_to?(:target_group_name) ? self.target_group_name : ENV.fetch('TARGET_GROUP_NAME', '') # rubocop:disable Style/RedundantSelf
      @_spot_capacity_provider_name ||= AwsSdkHelpers::Helpers.get_capacity_provider_name(target_group_name, 'Spot')
    end

    def _on_demand_capacity_provider_name
      target_group_name ||= self.respond_to?(:target_group_name) ? self.target_group_name : ENV.fetch('TARGET_GROUP_NAME', '') # rubocop:disable Style/RedundantSelf
      @_on_demand_capacity_provider_name ||= AwsSdkHelpers::Helpers.get_capacity_provider_name(target_group_name, 'OnDemand')
    end

    def _placement_strategy
      [
        {
          # Distribute across zones first
          'field': 'attribute:ecs.availability-zone',
          'type': 'spread',
        },
        {
          # Distribute across instances
          'field': 'instanceId',
          'type': 'spread',
        },
        {
          # Then try to maximize utilization (minimize number of EC2 instances)
          'field': 'memory',
          'type': 'binpack',
        },
      ]
    end

    def _placement_constraints
      [
        {
          'type': 'distinctInstance',
        },
      ]
    end
  end
end
