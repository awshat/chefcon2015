#!/bin/sh
# JSM: arguments 1:ChefServerPrivateKeyBucket 2:chef_server_url 3:chef_environment

# basically what we're doing here is fixing the hostname --fqdn command so it doesn't error
# by setting it our public hostname it will display the fqdn in the chef web module
hostname `curl http://169.254.169.254/latest/meta-data/public-hostname`

# Setup awscli on redhat
wget https://bootstrap.pypa.io/get-pip.py 
python get-pip.py 
pip install awscli 
rm get-pip.py

# get validation key from S3 bucket
mkdir -p /etc/chef/
cd /etc/chef
aws s3 cp s3://$1/chef-validator.pem /etc/chef/validation.pem 

# enabling sudo without tty (needed for chef-client web install to work)
sed -i 's/^.*requiretty/#Defaults requiretty/' /etc/sudoers

# install chef-client via mirrored version locked rpm
aws s3 cp s3://awshat-chefcon2015/chef-12.0.0-1.x86_64.rpm /tmp/chef-12.0.0-1.x86_64.rpm
rpm -ivh /tmp/chef-12.0.0-1.x86_64.rpm
#   or
# install latest chef-client via web
# curl -L https://www.opscode.com/chef/install.sh | sudo bash

(
cat << 'EOP'
{"run_list": ["recipe[aws]"]}
EOP
) > /etc/chef/first-boot.json
 
 
# createing client.rb for chef-client
NODE_NAME=`curl http://169.254.169.254/latest/meta-data/instance-id`
(
cat << EOP
ssl_verify_mode :verify_none
log_level :info
log_location STDOUT
node_name "$NODE_NAME"
chef_server_url '$2'
validation_client_name 'chef-validator'
environment "$3"
EOP
) > /etc/chef/client.rb
 
# running chef client
chef-client -j /etc/chef/first-boot.json
 
# preparing init script for unregistering from chef-server when destroying
(
cat << 'EOP'
#!/bin/sh
#
# chef_node     delete client and node
#

# chkconfig: 0 08 20
 
VAR_SUBSYS_CHEF_NODE="/var/lock/subsys/chef-node"
 
# Source function library.
. /etc/rc.d/init.d/functions
case "$1" in
    start)
        [ -f "$VAR_SUBSYS_CHEF_NODE" ] && exit 0
        touch $VAR_SUBSYS_CHEF_NODE
        RETVAL=$?
        ;;
    stop)
        NODE_NAME=`curl http://169.254.169.254/latest/meta-data/instance-id`
        knife node delete $NODE_NAME -y -c /etc/chef/client.rb -u $NODE_NAME
        knife client delete $NODE_NAME -y -c /etc/chef/client.rb -u $NODE_NAME
        \rm $VAR_SUBSYS_CHEF_NODE
        RETVAL=$?
        ;;
esac
exit $RETVAL
EOP
) > /etc/rc.d/init.d/chef-node
chmod 755 /etc/rc.d/init.d/chef-node
/sbin/chkconfig --level 2345 chef-node on
/sbin/chkconfig --level 0 chef-node off
/etc/rc.d/init.d/chef-node start 
