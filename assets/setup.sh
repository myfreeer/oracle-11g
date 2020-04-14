set -e

source /assets/colorecho
trap "echo_red '******* ERROR: Something went wrong.'; exit 1" SIGTERM
trap "echo_red '******* Caught SIGINT signal. Stopping...'; exit 2" SIGINT

#Install prerequisites directly without virtual package
deps () {
	echo_green "Installing dependencies"
	# openssh-server for sshd
	# psmsic for OPatch
	yum install -y openssl make gcc binutils gcc-c++ compat-libstdc++ \
		elfutils-libelf-devel elfutils-libelf-devel-static ksh \
		libaio libaio-devel numactl-devel sysstat unixODBC unixODBC-devel \
		pcre-devel glibc.i686 unzip sudo passwd openssh-server psmisc
	curl -L --progress-bar --output /assets/tini \
		"https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-amd64"
	curl -L --progress-bar --output /assets/gosu \
		"https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64"
	chmod 755 /assets/tini /assets/gosu
	yum clean all
	rm -rf /var/lib/{cache,log} /var/log/lastlog
}

users () {

	echo_green "Configuring users"
	groupadd -g 200 oinstall
	groupadd -g 201 dba
	useradd -u 440 -g oinstall -G dba -d /opt/oracle oracle
	echo "oracle:${SYS_ORACLE_PWD:-123456}" | chpasswd
	echo "root:${SYS_ROOT_PWD:-123456}" | chpasswd
	sed -i "s/pam_namespace.so/pam_namespace.so\nsession    required     pam_limits.so/g" \
		/etc/pam.d/login
	mkdir -p -m 755 /opt/oracle/app
	mkdir -p -m 755 /opt/oracle/oraInventory
	chown -R oracle:oinstall /opt/oracle
	chown -R oracle:oinstall /assets
	echo 'source "~oracle/.bashrc"' ~oracle/.bash_profile
	cat /assets/profile >> ~oracle/.bashrc
	ssh-keygen -q -t rsa -b 2048 -f /etc/ssh/ssh_host_rsa_key -N ''
	ssh-keygen -q -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N ''
	ssh-keygen -t dsa -f /etc/ssh/ssh_host_ed25519_key  -N ''
	sed -i "s/#UsePrivilegeSeparation.*/UsePrivilegeSeparation no/g" /etc/ssh/sshd_config
	sed -i "s/UsePAM.*/UsePAM no/g" /etc/ssh/sshd_config
	# disable dns lookup for faster connection
	sed -i '/GSSAPIAuthentication/c\GSSAPIAuthentication no\' /etc/ssh/sshd_config
	sed -i '/UseDNS/c\UseDNS no\' /etc/ssh/sshd_config
}

sysctl_and_limits () {

	cp /assets/sysctl.conf /etc/sysctl.conf
	cat /assets/limits.conf >> /etc/security/limits.conf

}

mk_user_script_dir () {

	mkdir -p -m 755 /opt/oracle/user_scripts
	mkdir -p -m 755 /opt/oracle/user_scripts/1-before-db-install \
		/opt/oracle/user_scripts/2-after-db-install \
		/opt/oracle/user_scripts/3-before-db-create \
		/opt/oracle/user_scripts/4-after-db-create \
		/opt/oracle/user_scripts/5-once-container-startup \
		/opt/oracle/user_scripts/6-before-db-startup \
		/opt/oracle/user_scripts/7-after-db-startup

	chown -R oracle:oinstall /opt/oracle/user_scripts

}

deps
users
sysctl_and_limits
mk_user_script_dir
