class apache {
	case $::operatingsystem {
   'RedHat', 'CentOS', 'Scientific', 'OracleLinux', 'OEL': {
			package { 'httpd' :
				ensure => installed
			}
			
			service { 'httpd' :
				ensure => running,
				hasstatus => true,
				hasrestart => true,
				enable => true
			}
	}
   'ubuntu', 'debian': {
			package { 'apache2' :
				ensure => installed
			}
			
			service { 'apache2' :
				ensure => running,
				hasstatus => true,
				hasrestart => true,
				enable => true
			}
		}
	}
}
