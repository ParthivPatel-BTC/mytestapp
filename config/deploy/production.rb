set :branch, 'master'
set :rails_env, :production
server '52.221.189.60', user: 'ubuntu', roles: %w(web app db)

set :ssh_options, {
  :user => "ubuntu",
  :forward_agent => true
}
