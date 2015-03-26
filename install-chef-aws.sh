#!/bin/bash

# basically what we're doing here is fixing the hostname --fqdn command so it doesn't error
# by setting our hostname to what resolves in reverse DNS by default for ec2 instances 
hostname `hostname`.ec2.internal

# Bootstrap chef            
cd /home/ec2-user/
wget https://s3.amazonaws.com/awshat-chefcon2015/chef-server-core-12.0.6-1.el6.x86_64.rpm
sleep 5
su - -c 'yum install -y /home/ec2-user/chef-server-core-12.0.6-1.el6.x86_64.rpm'
sleep 5
wget https://s3.amazonaws.com/awshat-chefcon2015/chefdk-0.3.0-1.x86_64.rpm 
sleep 5
su - -c 'yum install -y /home/ec2-user/chefdk-0.3.0-1.x86_64.rpm'
sleep 5
su - -c '/usr/bin/chef-server-ctl reconfigure'
sleep 5
su - -c '/usr/bin/chef-server-ctl start'
sleep 5
su - -c '/usr/bin/chef-server-ctl install opscode-manage'
sleep 5
su - -c '/usr/bin/opscode-manage-ctl reconfigure'
sleep 5
su - -c '/usr/bin/opscode-manage-ctl start'
sleep 5
mkdir /home/ec2-user/.chef/
su - -c '/usr/bin/chef-server-ctl user-create chef-admin "Chef Admin" chef-admin@awshat.com changemein1 > /home/ec2-user/.chef/chef-admin.pem' 
su - -c '/usr/bin/chef-server-ctl org-create chef "Chef Software, Inc." --association_user chef-admin > /home/ec2-user/.chef/chef-validator.pem'

# Setup knife environment in ec2-user
cd /home/ec2-user/.chef/
echo "# See http://docs.getchef.com/config_rb_knife.html" > knife.rb
echo " " >> knife.rb
echo "current_dir = File.dirname(__FILE__)" >> knife.rb
echo "log_level                :info" >> knife.rb
echo "log_location             STDOUT" >> knife.rb
echo "node_name                \"chef-admin\"" >> knife.rb
echo "client_key               \"#{current_dir}/chef-admin.pem\"" >> knife.rb
echo "validation_client_name   \"chef\""
echo "validation_key           \"#{current_dir}/chef-validator.pem\"" >> knife.rb
echo "chef_server_url          \"https://localhost/organizations/chef\"" >> knife.rb
echo "cache_type               'BasicFile'" >> knife.rb
echo "cache_options( :path => \"#{ENV['HOME']}/.chef/checksums\" )" >> knife.rb
echo "cookbook_path            [\"#{current_dir}/../chef-repo/cookbooks\"] " >> knife.rb


# Setup initial chef-repo
mkdir /home/ec2-user/chef-repo/
mkdir /home/ec2-user/chef-repo/cookbooks/
mkdir /home/ec2-user/chef-repo/databags/
mkdir /home/ec2-user/chef-repo/environments/
mkdir /home/ec2-user/chef-repo/roles/
cd /home/ec2-user/chef-repo/cookbooks/
wget https://s3.amazonaws.com/awshat-chefcon2015/aws-cookbook.gz 
tar -xzvf /home/ec2-user/chef-repo/cookbooks/aws-cookbook.gz
rm -rf /home/ec2-user/chef-repo/cookbooks/aws-cookbook.gz
chown -R ec2-user:ec2-user /home/ec2-user/

# Upload cookbooks
su - -c 'cd /home/ec2-user/; knife cookbook upload -a -o /home/ec2-user/chef-repo/cookbooks'

# Setup Chef Server 12 to start on reboots via rc.local 
echo " " >> /etc/rc.local
echo "# Start Chef Server 12 and Web Management UI " >> /etc/rc.local
echo "su - -c '/usr/bin/opscode-manage-ctl reconfigure' " >> /etc/rc.local
echo "su - -c '/usr/bin/opscode-manage-ctl start' " >> /etc/rc.local
echo "su - -c '/usr/bin/chef-server-ctl reconfigure' " >> /etc/rc.local
echo "su - -c '/usr/bin/chef-server-ctl restart' " >> /etc/rc.local

/etc/rc.local
exit 0
