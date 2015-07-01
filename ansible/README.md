# Local Vagrant Deploys

First, make sure you have set up and have a running instance of (E3 Vagrant)[https://github.com/elevatedthird/vagrant-ansible-cent-lamp].

First, you need to do to configure the ansible script to provision new local instances by editing the following variables in main.yml.

* `site_name` This is the name of your project directory in your docroot and is also used as the access domain for your site. By convention, this should be domain.suffix. However, it's not required. Example: OEDIT might be at `oedit.me`.
* `drupal_root` This is the subfolder withing your project repo where Drupal's index.php is stored. Typically, it is either site or docroot.
* `database_name` This is the name of the database that your site will use. It should match the database name in your settings.php.
* `database_user` This is the name of the database user that your site will use. It should match the database user in your settings.php. Typically, it is safer to have a unique user for each site.
* `database_pass` This is the password that database_user will use. It should match the database password in your settings.php.
* `database_path` This is a locally accesible path to a sql dump on your vagrant instance. I.E. It must either be stored in the vagrant instance itself, or accessible via the NFS shared folder /vagrant_data. *WARNING*: If you run this ansible script with this variable set to anything but 'none', whatever dump that the path points to will OVERWRITE any database already on your vagrant instance.

After that, you need only define a new line in your local hosts file (typically, /etc/hosts).

```
192.168.50.50 <site_name> # This should match the site_name above
192.168.50.50 www.<site_name> # This should match the site_name above
```

Example:
```
192.168.50.50 oedit.me
192.168.50.50 www.oedit.me
```

Finally, from the same directory as this README run the following command:
```
ansible-playbook main.yml
```
