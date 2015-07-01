# =============================================================================
# DEPLOYMENT RECIPE FOR DRUPAL SITES
# =============================================================================

# This recipe is for the automated deployment and environment configuration
# of Drupal sites in testing and production environments

# =========================================================================
# Init multistage
# =========================================================================

set :stages, []
set :default_stage, "develop"
set :deploy_subdir, "site"
set :multiyaml_stages, "config/config.yml"

# Dynamically load stages from YAML file
@stages_from_yaml = YAML.load_file("#{multiyaml_stages}")
@stages_from_yaml.keys.each do |stage|
    stages.push(stage.to_s);
end

require 'capistrano-multiyaml'

# =========================================================================
# Set server configuration
# =========================================================================

set :use_sudo, false

default_run_options[:pty] = true

# number of releases to keep
set :keep_releases, 8


# =========================================================================
# Deploy tasks
# =========================================================================

namespace :deploy do
# derive site paths from site configuration
task :set_paths do

    logger.info "Setting configuration for #{application} #{stage}"
    set :deploy_to, "#{site_root}/application"
    set :current_path, "#{deploy_to}/current"
    set :shared_path, "#{deploy_to}/shared"

    set :shared_default_site_path, "#{shared_path}/default"
    set :shared_default_site_files_path, "#{shared_default_site_path}/files"
    set :shared_default_site_private_path, "#{shared_path}/private"
    set :shared_default_site_tmp_path, "#{shared_path}/private/tmp"

  end

  before "deploy:setup", "deploy:set_paths"
  before "deploy", "deploy:set_paths"
  before "deploy", "deploy:production_verify"
  before "deploy", "deploy:set_git_config"
  before "deploy", "deploy:releases_dir_check"
  after "deploy", "deploy:create_site_structure"
  after "deploy", "deploy:create_data_symlinks"
  after "deploy", "deploy:create_env_robots"
  after "deploy", "deploy:cleanup"
  after "deploy", "deploy:upload_local_files"

  desc "Set up the expected application directory structure on all boxes"
  task :setup, :except => { :no_release => true } do
    logger.info "Creating initial site folder structure."
    run "rm -rf #{deploy_to}/test"
    run "mkdir -p #{deploy_to} #{releases_path} #{shared_path} #{shared_default_site_path} #{shared_default_site_files_path} #{shared_default_site_private_path} #{shared_default_site_tmp_path}"
    run "chown #{file_owner_user} #{deploy_to} #{releases_path} #{shared_path} #{shared_default_site_path} #{shared_default_site_files_path} #{shared_default_site_private_path} #{shared_default_site_tmp_path}"
    # give this user and apache write access to the shared
    run "chown -R #{file_owner_user}:#{web_server_user} -R #{shared_default_site_files_path}"
    run "chmod 775 -R #{shared_default_site_files_path}"
    # give this user and apache write access to the shared
    run "chown -R #{file_owner_user}:#{web_server_user} -R #{shared_default_site_private_path}"
    run "chmod 775 -R #{shared_default_site_private_path}"
    logger.info "Creating .ssh folder for password-less access"
    run "mkdir -p #{site_root}/.ssh"
    run "chown #{file_owner_user} #{site_root}/.ssh"
    run "chmod 700 -R #{site_root}/.ssh"
  end

  task :launch do
    logger.info "Creating symlink to site running in #{current_path}"
    # link names that we don't want to clobber
    httpdirs = ["#{site_root}/#{site_htdocs}", "#{site_root}/#{site_htsdocs}"]
    for httpdir in httpdirs
      # see if file already exists on server
      set :httpdir_exist, capture("find #{site_root} -path #{httpdir} | wc -l").chomp!
      # if the file exists
      if ("#{httpdir_exist}" != "0")
        logger.info "File/directory already exists. Backing up..."
        # backup the file/dir then create symlink
        run "mv #{httpdir} #{httpdir}_old_$(date +%Y%m%d%H%M%S) && ln -sf #{current_path} #{httpdir}"
      else
        # nothing there, so just make the symlink to current
        run "ln -sf #{current_path} #{httpdir}"
      end
    end
  end

  # make sure nothing weird got created in releases directory.
  # proceeding otherwise could break the site
  task :releases_dir_check do
    # check releases dir for anything that doesn't start with 20
    set :unauthorized_dirs, capture("ls -1 #{releases_path} | grep -v ^20 | wc -l").chomp!
    # if any bad directories are detected, abort deployment
    if ("#{unauthorized_dirs}" != "0")
      logger.info "Ew, your releases directory isn't clean. You should be ashamed. Or, maybe you just forgot to run the deploy:setup task first."
      error = CommandError.new("Aborting deployment")
      raise error
    end
  end

  # derive git set up from site configuration
  task :production_verify do
    # if production environment, confirm deployment.
    if ("#{stage}" == "production")
      production_confirmation = Capistrano::CLI.ui.ask("Confirm deployment to production(y/N):")
      if !(production_confirmation.downcase == "y" || production_confirmation.downcase == "yes")
        error = CommandError.new("Aborting deployment")
        raise error
      end
    end
  end
  # derive git set up from site configuration
  task :set_git_config do
    set :scm, "git"
    set :scm_verbose, true
    ssh_options[:forward_agent] = true
    set :repository,  "git@github.com:elevatedthird/#{git_name}.git"
    set :deploy_via, :remote_cache
  end

  task :update do
    transaction do
      update_code
      symlink
    end
  end

  task :symlink do
    transaction do
        run "ln -nfs #{current_release} #{deploy_to}/#{current_dir}"
        # run "rm -Rf #{document_root}"
        # run "ln -nfs #{deploy_to}/#{current_dir} #{document_root}"
    end
  end

  task :finalize_update do
    transaction do
    end
  end

  task :create_site_structure do
    transaction do
      # move stage specific settings.php into default folder
      run "if [ -f #{current_path}/sites/default/#{stage}.settings.php ]; then mv -f #{current_path}/sites/default/#{stage}.settings.php #{shared_default_site_path}/settings.php; fi"
      # rename <stage>.htaccess to default .htaccess if existent
      run "if [ -f #{current_path}/#{stage}.htaccess ]; then mv -f #{current_path}/#{stage}.htaccess #{current_path}/.htaccess; fi"
    end
  end

  task :create_data_symlinks do
    transaction do
      run "rm -rf #{current_path}/sites/default"
      run "ln -nfs #{shared_path}/default #{current_path}/sites"
    end
  end

  task :create_env_robots do
    transaction do
      if !("#{stage}" == "production")
        run "echo -e 'User-agent: * \\nDisallow: \/' > #{current_path}/robots.txt"
      end
    end
  end

  task :upload_local_files do
    transaction do
      current_host = capture("echo $CAPISTRANO:HOST$").strip
      set :default_files, "#{deploy_to}/shared/default/files"
      new_files_dir = "../upload/new/#{stage}/files"
      old_files_dir = "../upload/old/#{stage}/files"
      remote_files_dir = "#{default_files}"
      remote_target = "#{user}@#{current_host}:#{remote_files_dir}"
      files_to_upload = `
          if [ -d #{new_files_dir} ]; then
            if [ \"$(ls -A #{new_files_dir})\" ]; then
              echo -n yes;
            fi;
          fi
      `
      if (files_to_upload == "yes")
        system "
            if [ -d #{new_files_dir} ]; then
              if [ \"$(ls -A #{new_files_dir})\" ]; then
                rsync -ave ssh -ni #{new_files_dir}/ #{remote_target}/;
              fi;
            fi
        "

        rsync_confirmation = Capistrano::CLI.ui.ask("\nReview rsync dry run output before proceeding.\nPlease refer here for more information:\nhttp://andreafrancia.it/2010/03/understanding-the-output-of-rsync-itemize-changes.html\nAre you ok with the proposed changes to the #{stage} filesystem? (y/N):")
        if (rsync_confirmation.downcase == "y" || rsync_confirmation.downcase == "yes")
          system "
              rsync -ave ssh #{new_files_dir}/ #{remote_target}/;

              datestamp=\"`date +%Y%m%d%H%M%S`\";
              old_target=\"#{old_files_dir}/$datestamp\";

              if [ ! -d $old_target ]; then
                mkdir -p $old_target;
              fi;

              rsync -av #{new_files_dir}/ $old_target/ && \
              rm -rf #{new_files_dir}/*;
          "
        end

        run "chown -R #{file_owner_user}:#{web_server_user} -R #{default_files}"
        run "chmod 775 -R #{default_files}"

        if (rsync_confirmation.downcase == "y" || rsync_confirmation.downcase == "yes")
          puts " "
          puts "Please review rsync output for errors."
          puts " "
        end

      end

    end
  end

  task :create_site do

      current_host = capture("echo $CAPISTRANO:HOST$").strip
      date_stamp = `date +%Y%m%d%H%M%S`.chomp!

      # Make sure we have the commands we need...
      find_commands = ['drush', 'mysql', 'mysqldump', 'gzip', 'gunzip']
      puts "\nEnsuring we have the required commands available...\n\n"

      for command in find_commands
        find_command = "which #{command}"

        output_commands = ["#{find_command}", "ssh #{user}@#{current_host} \"#{find_command}\""]
        for out in output_commands
          output = `#{out}`
          if !($?.success?)
            error = CommandError.new("\nCouldn't find #{command} command. Aborting.\n\n")
            raise error
          end
        end
      end

      # MySQL credentials file needs to look like the following:
      #
      #     [client]
      #     user=root
      #     password=pass
      #
      # Also, it's best to set this file's permissions to 400

      mysql_user_creds_file = "/etc/mysql.creds"

      set :mysql_user_creds_file_exists, capture("if [ -e #{mysql_user_creds_file} ]; then echo yes; else echo no; fi").chomp!
      if ("#{mysql_user_creds_file_exists}" == "no")
        mysql_creds_err = "\nERROR: file #{mysql_user_creds_file} not found.\n\tRemote MySQL admin credentials could not be determined. Aborting.\n"
        mysql_creds_err << "\nMySQL credentials file needs to look like the following:\n"
        mysql_creds_err << "\n\t[client]\n\tuser=root\n\tpassword=pass\n"
        mysql_creds_err << "\nFailure to set this file's permissions to 400 is punishable by one of the\nfollowing, and punishment is randomly drawn, by you, from the trash can\nmost recently assailed by Griffin.\n"
        mysql_creds_err << "\n  1) One hand is tied behind your back for next month's Foosball tournaments.\n  2) You must turn off the music on the following Tuesday at 10AM and shout a\n     sonnet touching on the subtle differences between unix and eunuchs.\n  3) Bill O'Reilly's rage-spittle.\n\n"
        error = CommandError.new("#{mysql_creds_err}")
        raise error
      end

      site_root_local = "../site"
      backups_dir_local = "../backups/local"
      drush_st = "drush st --show-passwords"
      drush_awk = "awk -F':  ' '{print $2}'"
      mysql_db_name_local = `
        (cd #{site_root_local} && #{drush_st} | grep 'Database name' | #{drush_awk})
      `.rstrip.lstrip
      mysql_db_user_local = `
        (cd #{site_root_local} && #{drush_st} | grep 'Database username' | #{drush_awk})
      `.rstrip.lstrip
      mysql_db_pass_local = `
        (cd #{site_root_local} && #{drush_st} | grep 'Database password' | #{drush_awk})
      `.rstrip.lstrip
      mysql_db_host_local = `
        (cd #{site_root_local} && #{drush_st} | grep 'Database hostname' | #{drush_awk})
      `.rstrip.lstrip

      if !(mysql_db_host_local.length > 1)
        mysql_db_host_local = "localhost"
      end

      set :already_deployed, capture("if [ -d #{deploy_to} ]; then echo yes; else echo no; fi").chomp!
      if ("#{already_deployed}" == "yes")
        error = CommandError.new("\nThe #{stage} site appears to have already been deployed. Aborting.\n\n")
        raise error
      else
        puts "INFO: site not yet deployed. That's good."
      end

      set :site_root_exists, capture("if [ -d #{site_root} ]; then echo yes; else echo no; fi").chomp!
      if ("#{site_root_exists}" == "no")
        run "mkdir -p #{site_root}"
      end
      system("cap #{stage} deploy:setup && cap #{stage} deploy && cap #{stage} deploy:launch")
      #create_launch = Capistrano::CLI.ui.ask("\nDeployment complete. Run launch task? (y/N):")
      #if (create_launch.downcase == "y" || create_launch.downcase == "yes")
      #  system("cap #{stage} deploy:launch")
      #end

      drush_st_remote = capture("cd #{deploy_to}/current && #{drush_st}").chomp!
      drush_st_remote_tmp = "/tmp/drush_st_#{date_stamp}"
      File.open("#{drush_st_remote_tmp}", 'w') { |file| file.write("#{drush_st_remote}") }

      mysql_db_name_remote = `grep 'Database name' #{drush_st_remote_tmp} | #{drush_awk}`.rstrip.lstrip
      mysql_db_user_remote = `grep 'Database username' #{drush_st_remote_tmp} | #{drush_awk}`.rstrip.lstrip
      mysql_db_pass_remote = `grep 'Database password' #{drush_st_remote_tmp} | #{drush_awk}`.rstrip.lstrip
      mysql_db_host_remote = `grep 'Database hostname' #{drush_st_remote_tmp} | #{drush_awk}`.rstrip.lstrip

      system("rm #{drush_st_remote_tmp}")

      if !(mysql_db_host_remote.length > 1)
        mysql_db_host_remote = "localhost"
      end

      db_dump = `echo "#{mysql_db_name_local}-db-local-#{date_stamp}.sql.gz"`
      db_dump_full = "#{backups_dir_local}/#{db_dump}".chomp!

      system("if [ ! -d #{backups_dir_local} ]; then mkdir -p #{backups_dir_local}; fi")
      system("mysqldump -u #{mysql_db_user_local} -p#{mysql_db_pass_local} \
             -h #{mysql_db_host_local} #{mysql_db_name_local} \
             | gzip > #{db_dump_full}")

      remote_tmp_dir = "/tmp"
      system("scp #{db_dump_full} #{user}@#{current_host}:#{remote_tmp_dir}")

      mysql_run = "mysql --defaults-extra-file=#{mysql_user_creds_file}"
      mysql_create = "create database if not exists #{mysql_db_name_remote}"
      mysql_grant = "grant all on #{mysql_db_name_remote}.* to #{mysql_db_user_remote}@#{mysql_db_host_remote} identified by '#{mysql_db_pass_remote}'"

      run "#{mysql_run} -e \"#{mysql_create}\""

      run "#{mysql_run} -e \"#{mysql_grant}\""

      db_dump_remote_full ="#{remote_tmp_dir}/#{db_dump}"

      mysql_remote_count = "#{mysql_run} #{mysql_db_name_remote} -e \"select count(*) from information_schema.tables where table_type = 'BASE TABLE' and table_schema = '#{mysql_db_name_remote}'\" | tail -1"
      set :mysql_remote_empty, capture("#{mysql_remote_count}").chomp!

      # Only import if database is empty
      if ("#{mysql_remote_empty}" == "0")
        run "gunzip < #{db_dump_remote_full} | #{mysql_run} #{mysql_db_name_remote}"
      else
        db_already_populated = true
      end

      run "rm #{db_dump_remote_full}"

      current_host = capture("echo $CAPISTRANO:HOST$").strip
      local_files_dir = "#{site_root_local}/sites/default/files"
      set :default_files, "#{deploy_to}/shared/default/files"
      remote_files_dir = "#{default_files}"
      remote_target = "#{user}@#{current_host}:#{remote_files_dir}"

      system("rsync -ave ssh #{local_files_dir}/ #{remote_target}/")

      run "chown -R #{file_owner_user}:#{web_server_user} -R #{default_files}"
      run "chmod 775 -R #{default_files}"

      # Vhost creation support for CentOS/RHEL only at this time.
      apache_conf_dir = "/etc/httpd/conf.d"
      set :apache_conf_dir_exists, capture("if [ -d #{apache_conf_dir} ]; then echo yes; else echo no; fi").chomp!
      if ("#{apache_conf_dir_exists}" == "yes")
        set :plesk_server, capture("if [ -e /usr/local/psa/version ]; then echo yes; else echo no; fi").chomp!
        if ("#{plesk_server}" == "yes")
          plesk_server_run_away = true
        else
          apache_skel = "#{apache_conf_dir}/e3.skel"
          apache_vhost = "#{apache_conf_dir}/#{site_url}.conf"

          set :apache_skel_exists, capture("if [ -e #{apache_skel} ]; then echo yes; else echo no; fi").chomp!
          if ("#{apache_skel_exists}" == "yes")
            remote_hostname = capture("hostname -f").chomp!
            run "cp #{apache_skel} #{apache_vhost}"
            run "sed -i 's/hostnamefqdn/#{remote_hostname}/g' #{apache_vhost}"
            run "sed -i 's/e3skeldomain/#{site_url}/g' #{apache_vhost}"
            run "sed -i 's/sitehtdocs/#{site_htdocs}/g' #{apache_vhost}"
            run "sed -i 's:e3skelsiteroot:#{site_root}:g' #{apache_vhost}"
            run "service httpd reload"
          else
            apache_skel_doesnt_exist = true

            # e3.skel should contain:
            #
            # <VirtualHost *:80>
            #     ServerName e3skeldomain
            #     ServerAlias www.e3skeldomain
            #     ServerAlias e3skeldomain.hostnamefqdn
            #     ServerAlias www.e3skeldomain.hostnamefqdn
            #     DocumentRoot e3skelsiteroot/sitehtdocs
            #
            #     <Directory e3skelsiteroot/sitehtdocs>
            #         Options Indexes FollowSymLinks MultiViews
            #         AllowOverride All
            #         Order allow,deny
            #         Allow from all
            #         DirectoryIndex index.php index.html
            #     </Directory>
            # </VirtualHost>

          end
        end
      else
        couldnt_find_apache_conf_dir = true
      end

      if ("#{db_already_populated}" == "true")
        puts "\nERROR: #{stage} #{mysql_db_name_remote} database is not empty! Skipping import so you don't inadvertently clobber the fine work of your colleagues. Be more careful next time.\n\n"
      end

      if ("#{couldnt_find_apache_conf_dir}" == "true")
        puts "\nERROR: Couldn't find Apache's conf directory. Skipping vhost autoconfiguration.\n\n"
      end

      if ("#{plesk_server_run_away}" == "true")
        puts "\nERROR: Plesk detected, so we'll abort vhost autoconfiguration. You'll thank me later.\n\n"
      end

      if ("#{apache_skel_doesnt_exist}" == "true")
        puts "\nERROR: Apache skel file (#{apache_skel}) doesn't exist. Skipping vhost autoconfig.\n\n"
      end

      puts "If all went well, your new #{stage} site should be ready here: \nhttp://#{site_url}/\n\n"

  end


  # Each of the following tasks are Rails specific. They're removed.
  task :migrate do
  end

  task :migrations do
  end

  task :cold do
  end

  task :start do
  end

  task :stop do
  end

  task :restart do
  end


end