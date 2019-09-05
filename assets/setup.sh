set -e

source /assets/colorecho
trap "echo_red '******* ERROR: Something went wrong.'; exit 1" SIGTERM
trap "echo_red '******* Caught SIGINT signal. Stopping...'; exit 2" SIGINT

#Install prerequisites directly without virtual package
deps () {
	echo "Installing dependencies"
	yum install -y openssl make gcc binutils gcc-c++ compat-libstdc++ \
		elfutils-libelf-devel elfutils-libelf-devel-static ksh \
		libaio libaio-devel numactl-devel sysstat unixODBC unixODBC-devel \
		pcre-devel glibc.i686 unzip sudo passwd openssh-server
	yum clean all
	rm -rf /var/lib/{cache,log} /var/log/lastlog
}

users () {

	echo "Configuring users"
	groupadd -g 200 oinstall
	groupadd -g 201 dba
	useradd -u 440 -g oinstall -G dba -d /opt/oracle oracle
	echo "oracle:123456" | chpasswd
	echo "root:123456" | chpasswd
	sed -i "s/pam_namespace.so/pam_namespace.so\nsession    required     pam_limits.so/g" /etc/pam.d/login
	mkdir -p -m 755 /opt/oracle/app
	mkdir -p -m 755 /opt/oracle/oraInventory
	mkdir -p -m 755 /opt/oracle/dpdump
	chown -R oracle:oinstall /opt/oracle
	cat /assets/profile >> ~oracle/.bash_profile
	cat /assets/profile >> ~oracle/.bashrc
	ssh-keygen -q -t rsa -b 2048 -f /etc/ssh/ssh_host_rsa_key -N ''
	ssh-keygen -q -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N ''
	ssh-keygen -t dsa -f /etc/ssh/ssh_host_ed25519_key  -N ''
	sed -i "s/#UsePrivilegeSeparation.*/UsePrivilegeSeparation no/g" /etc/ssh/sshd_config
	sed -i "s/UsePAM.*/UsePAM no/g" /etc/ssh/sshd_config
}

sysctl_and_limits () {

	cp /assets/sysctl.conf /etc/sysctl.conf
	cat /assets/limits.conf >> /etc/security/limits.conf

}

deps
users
sysctl_and_limits
