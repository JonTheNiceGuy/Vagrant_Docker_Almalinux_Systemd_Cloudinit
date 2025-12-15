# Vagrant plugin to support cloud-init with Docker provider
# This plugin provides a docker_cloud_init helper method and sets up
# the NoCloud datasource for cloud-init in Docker containers

require 'fileutils'

module VagrantPlugins
  module DockerCloudInit
    # Helper class for block-style configuration
    class CloudInitConfigHelper
      attr_accessor :type, :content_type, :path, :inline

      def initialize(type)
        @type = type
        @content_type = "text/cloud-config"
      end
    end

    # Configuration class for docker_cloud_init
    class Config < Vagrant.plugin("2", :config)
      attr_accessor :user_data_content_type
      attr_accessor :user_data_inline
      attr_accessor :user_data_path

      attr_accessor :meta_data_content_type
      attr_accessor :meta_data_inline
      attr_accessor :meta_data_path

      attr_accessor :vendor_data_content_type
      attr_accessor :vendor_data_inline
      attr_accessor :vendor_data_path

      attr_accessor :network_config_content_type
      attr_accessor :network_config_inline
      attr_accessor :network_config_path

      def initialize
        @user_data_content_type = UNSET_VALUE
        @user_data_inline = UNSET_VALUE
        @user_data_path = UNSET_VALUE

        @meta_data_content_type = UNSET_VALUE
        @meta_data_inline = UNSET_VALUE
        @meta_data_path = UNSET_VALUE

        @vendor_data_content_type = UNSET_VALUE
        @vendor_data_inline = UNSET_VALUE
        @vendor_data_path = UNSET_VALUE

        @network_config_content_type = UNSET_VALUE
        @network_config_inline = UNSET_VALUE
        @network_config_path = UNSET_VALUE
      end

      # Provide block-style configuration for user_data
      def user_data(&block)
        helper = CloudInitConfigHelper.new(:user_data)
        block.call(helper) if block_given?

        @user_data_content_type = helper.content_type
        @user_data_inline = helper.inline
        @user_data_path = helper.path
      end

      # Provide block-style configuration for meta_data
      def meta_data(&block)
        helper = CloudInitConfigHelper.new(:meta_data)
        block.call(helper) if block_given?

        @meta_data_content_type = helper.content_type
        @meta_data_inline = helper.inline
        @meta_data_path = helper.path
      end

      def finalize!
        @user_data_content_type = "text/cloud-config" if @user_data_content_type == UNSET_VALUE
        @user_data_inline = nil if @user_data_inline == UNSET_VALUE
        @user_data_path = nil if @user_data_path == UNSET_VALUE

        @meta_data_content_type = "text/cloud-config" if @meta_data_content_type == UNSET_VALUE
        @meta_data_inline = nil if @meta_data_inline == UNSET_VALUE
        @meta_data_path = nil if @meta_data_path == UNSET_VALUE

        @vendor_data_content_type = "text/cloud-config" if @vendor_data_content_type == UNSET_VALUE
        @vendor_data_inline = nil if @vendor_data_inline == UNSET_VALUE
        @vendor_data_path = nil if @vendor_data_path == UNSET_VALUE

        @network_config_content_type = "text/cloud-config" if @network_config_content_type == UNSET_VALUE
        @network_config_inline = nil if @network_config_inline == UNSET_VALUE
        @network_config_path = nil if @network_config_path == UNSET_VALUE
      end

      def validate(machine)
        errors = _detected_errors
        { "Docker Cloud-Init" => errors }
      end
    end

    class Plugin < Vagrant.plugin("2")
      name "Docker Cloud-Init Support"

      # Register the docker_cloud_init configuration
      config("docker_cloud_init") do
        Config
      end

      action_hook(:docker_cloudinit, :machine_action_up) do |hook|
        hook.before(VagrantPlugins::DockerProvider::Action::Create, Action::PrepareCloudInit)
      end

      action_hook(:docker_cloudinit, :machine_action_destroy) do |hook|
        hook.append(Action::CleanupCloudInit)
      end

      action_hook(:docker_cloudinit, :machine_action_halt) do |hook|
        hook.append(Action::CleanupCloudInit)
      end
    end

    module Action
      class PrepareCloudInit
        def initialize(app, env)
          @app = app
        end

        def call(env)
          machine = env[:machine]

          # Only process Docker provider
          unless machine.provider_name == :docker
            @app.call(env)
            return
          end

          # Check if docker_cloud_init configuration exists
          docker_ci_config = machine.config.docker_cloud_init
          cloud_init_configs = []

          # Extract user_data if configured
          if docker_ci_config.user_data_inline || docker_ci_config.user_data_path
            cloud_init_configs << {
              type: :user_data,
              content_type: docker_ci_config.user_data_content_type,
              path: docker_ci_config.user_data_path,
              inline: docker_ci_config.user_data_inline
            }
          end

          # Extract meta_data if configured
          if docker_ci_config.meta_data_inline || docker_ci_config.meta_data_path
            cloud_init_configs << {
              type: :meta_data,
              content_type: docker_ci_config.meta_data_content_type,
              path: docker_ci_config.meta_data_path,
              inline: docker_ci_config.meta_data_inline
            }
          end

          # Extract vendor_data if configured
          if docker_ci_config.vendor_data_inline || docker_ci_config.vendor_data_path
            cloud_init_configs << {
              type: :vendor_data,
              content_type: docker_ci_config.vendor_data_content_type,
              path: docker_ci_config.vendor_data_path,
              inline: docker_ci_config.vendor_data_inline
            }
          end

          # Extract network_config if configured
          if docker_ci_config.network_config_inline || docker_ci_config.network_config_path
            cloud_init_configs << {
              type: :network_config,
              content_type: docker_ci_config.network_config_content_type,
              path: docker_ci_config.network_config_path,
              inline: docker_ci_config.network_config_inline
            }
          end

          if cloud_init_configs.empty?
            @app.call(env)
            return
          end

          env[:ui].info("Setting up cloud-init NoCloud datasource for Docker container")

          # Create a temporary directory for cloud-init files
          root_path = env[:root_path]
          cloudinit_dir = File.join(root_path, ".vagrant", "cloudinit", machine.name.to_s)
          FileUtils.mkdir_p(cloudinit_dir)

          # Write cloud-init files
          has_meta_data = false
          cloud_init_configs.each do |config|
            case config[:type]
            when :user_data
              write_cloud_init_file(cloudinit_dir, "user-data", config, env, root_path)
            when :meta_data
              write_cloud_init_file(cloudinit_dir, "meta-data", config, env, root_path)
              has_meta_data = true
            when :network_config
              write_cloud_init_file(cloudinit_dir, "network-config", config, env, root_path)
            when :vendor_data
              write_cloud_init_file(cloudinit_dir, "vendor-data", config, env, root_path)
            end
          end

          # Create minimal meta-data if not provided
          # NoCloud datasource requires meta-data to exist even if empty
          unless has_meta_data
            meta_data_content = "instance-id: #{machine.name}\nlocal-hostname: #{machine.config.vm.hostname || machine.name}\n"
            File.write(File.join(cloudinit_dir, "meta-data"), meta_data_content)
            env[:ui].info("  Created meta-data (auto-generated)")
          end

          # Add volume mounts to Docker provider config
          provider_config = machine.provider_config

          # Mount the cloud-init directory to the NoCloud location
          # Cloud-init looks for NoCloud data in /var/lib/cloud/seed/nocloud/
          nocloud_path = "/var/lib/cloud/seed/nocloud"

          # Get or initialize volumes array
          volumes = provider_config.volumes || []

          # Add our cloud-init directory as a volume
          volumes << "#{cloudinit_dir}:#{nocloud_path}:ro"
          provider_config.volumes = volumes

          env[:ui].success("Cloud-init files prepared at #{cloudinit_dir}")
          env[:ui].info("Files will be mounted at #{nocloud_path} in container")

          @app.call(env)
        end

        private

        def write_cloud_init_file(dir, filename, config, env, root_path)
          file_path = File.join(dir, filename)

          content = if config[:path]
            # Read from external file
            # Resolve relative paths from Vagrantfile directory
            source_path = config[:path]
            unless Pathname.new(source_path).absolute?
              source_path = File.join(root_path, source_path)
            end
            File.read(source_path)
          elsif config[:inline]
            # Use inline content
            config[:inline]
          else
            return
          end

          # Ensure content starts with appropriate header based on content_type
          if config[:content_type] == "text/cloud-config" && !content.start_with?("#cloud-config")
            content = "#cloud-config\n#{content}"
          elsif config[:content_type] == "text/x-shellscript" && !content.start_with?("#!")
            content = "#!/bin/bash\n#{content}"
          end

          File.write(file_path, content)
          env[:ui].info("  Created #{filename}")
        end
      end

      class CleanupCloudInit
        def initialize(app, env)
          @app = app
        end

        def call(env)
          @app.call(env)

          machine = env[:machine]

          # Only process Docker provider
          return unless machine.provider_name == :docker

          # Clean up cloud-init directory for this machine
          root_path = env[:root_path]
          cloudinit_dir = File.join(root_path, ".vagrant", "cloudinit", machine.name.to_s)

          if File.directory?(cloudinit_dir)
            FileUtils.rm_rf(cloudinit_dir)
            env[:ui].info("Cleaned up cloud-init files")
          end

        end
      end
    end
  end
end
