# config valid only for current version of Capistrano
lock "3.11.0"

set :application,     'mytestapp'
server '52.221.189.60', roles: [:web, :app, :db], primary: true
set :repo_url,        'git@github.com:ParthivPatel-BTC/mytestapp.git'
set :user,            'ubuntu'
set :branch,           'master'
set :deploy_to,       "/home/#{fetch(:user)}/apps/#{fetch(:application)}"
set :ssh_options,    { forward_agent: true, user: fetch(:user), keys: %w(~/.ssh/id_new_rsa) }
set :stage,           :production
set :rails_env,       :production
set :pty,             false
set :use_sudo,        false
set :deploy_via,      :remote_cache

set :linked_files, %w{config/database.yml config/secrets.yml config/application.yml}
set :linked_dirs, %w{log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system public/uploads public/assets}

set :whenever_identifier, ->{ "#{fetch(:application)}_#{fetch(:stage)}" }
set :whenever_command, [:bundle, :exec, :whenever]

namespace :puma do
  desc 'Create Directories for Puma Pids and Socket'
  task :make_dirs do
    on roles(:app) do
      execute "mkdir #{shared_path}/tmp/sockets -p"
      execute "mkdir #{shared_path}/tmp/pids -p"
    end
  end

  #before :start, :make_dirs
end

namespace :deploy do
  desc "Make sure local git is in sync with remote."
  task :check_revision do
    on roles(:app) do
      # unless `git rev-parse HEAD` == `git rev-parse origin/production_release_5th_sept`
      #   puts "WARNING: HEAD is not the same as origin/master"
      #   puts "Run `git push` to sync changes."
      #   exit
      # end
    end
  end

  desc 'Initial Deploy'
  task :initial do
    on roles(:app) do
      before 'deploy:restart', 'puma:start'
      invoke 'deploy'
    end
  end

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      invoke 'puma:restart'
    end
  end

  before :starting,     :check_revision
  after  :finishing,    :compile_assets
  after  :finishing,    :cleanup
  after  :finishing,    :restart
end

# ps aux | grep puma    # Get puma pid
# kill -s SIGUSR2 pid   # Restart puma
# kill -s SIGTERM pid   # Stop puma



namespace :deploy do

  desc "Upload yml files - cap production deploy:upload_yml"
  task :upload_yml do
    on roles(:app) do
      execute "mkdir -p #{shared_path}/config"
      upload! StringIO.new(File.read("config/application.yml")), "#{shared_path}/config/application.yml"
      upload! StringIO.new(File.read("config/database.yml")), "#{shared_path}/config/database.yml"
      upload! StringIO.new(File.read("config/secrets.yml")), "#{shared_path}/config/secrets.yml"
    end
  end

  desc 'Runs rake db:seed and other seeds - cap production deploy:seed'
  task :seed => [:set_rails_env] do
    on primary fetch(:migration_role) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "db:seed db:currency_to_country db:system_emails"
        end
      end
    end
  end

  desc 'Runs rake db:drop - cap production deploy:drop'
  task :drop => [:set_rails_env] do
    on primary fetch(:migration_role) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "db:drop"
        end
      end
    end
  end

  desc 'Runs rake jobs:clear - cap production deploy:jobs_clear'
  task :jobs_clear => [:set_rails_env] do
    on primary fetch(:migration_role) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "jobs:clear"
        end
      end
    end
  end

end

namespace :rails do
  desc "Open the rails console on the remote app server -  cap production rails:console"
  task :console => 'rvm:hook' do
    on roles(:app), :primary => true do |host|
      execute_interactively host, "console #{fetch(:stage)}"
    end
  end

  desc "Open the rails dbconsole on each of the remote servers -  cap production rails:dbconsole"
  task :dbconsole => 'rvm:hook' do
    on roles(:app), :primary => true do |host|
      execute_interactively host, "dbconsole #{fetch(:stage)}"
    end
  end

  def execute_interactviely(host, command)
    command = "cd #{fetch(:deploy_to)}/current && #{SSHKit.config.command_map[:bundle]} exec rails #{command}"
    puts command if fetch(:log_level) == :debug
    exec "ssh -l #{host.user} #{host.hostname} -p #{host.port || 22} -t '#{command}'"
  end
end


after 'deploy:publishing', 'deploy:restart'
namespace :deploy do
  task :restart do
    invoke 'delayed_job:restart'
  end
end
