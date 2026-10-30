# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include condor::worker::install
class condor::worker::install(
  String $supported_vos = 'cms lhcb atlas dune gridpp ops',
  $use_official_repo = false, ## If true this will use the HTCondor repo instead of downloading condor from EPEL.
  $schedd_fqdn = '',
  Sensitive $schedd_password = '',
  # $disable_firewalld = false, ## If your setup uses border firewalls. This currently does nothing as functionality not implemented yet!
  # $configure_selinux = false, ## If your setup uses SELinux
  $scratch_directory = '/scratch'
) {
  $_wlcg_packages = ['apptainer', 'HEP_OSlibs', 'wlcg-iam*', 'wlcg-voms*', 'fetch-crl', 'bind-utils', 'java-latest-openjdk', 'wget', 'bc']

  package {'epel-release':
    ensure => installed,
  }

  exec { 'enable_crb_repo':
    command => '/usr/bin/dnf config-manager --set-enabled crb',
    unless  => '/usr/bin/dnf repolist enabled | /usr/bin/grep -qi "^crb"',
  }

  package {$_wlcg_packages: ensure => installed}

  if $use_official_repo { ## TODO: Check for EL10
    package {'htcondor-release-25.0-1.el9.noarch':
      ensure => installed,
      source => 'https://htcss-downloads.chtc.wisc.edu/repo/25.0/htcondor-release-current.el9.noarch.rpm'
    }

    package {'condor':
      ensure => installed
    }
  }else {
    package {'condor':
      ensure => installed,
    }
  }

  $_split_vos = $supported_vos.split(' ')
  class {'condor::usermaps':
    vos_supported => $_split_vos
  }

  # if $disable_firewalld {
  #   service {'firewalld':
  #     ensure => 'stopped',
  #     enable => false
  #   }
  # }

  service {'firewalld':
    ensure => 'stopped',
    enable => false
  }

  # if $configure_selinux {
  #   selinux::fcontext { '/scratch(/.*)?':
  #     seltype => 'tmp_t',
  #   }

  #   exec { 'restorecon-scratch':
  #     command => '/sbin/restorecon -Rv /scratch',
  #   }

  #   exec { 'use-nfs-home-dirs':
  #     command => '/usr/sbin/setsebool -P use_nfs_home_dirs on',
  #     unless  => '/usr/sbin/getsebool use_nfs_home_dirs | grep -- "on$"',
  #   }
  # }

  file {'/etc/condor/config.d/01-execute.config':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @("EOF")
      CONDOR_HOST = ${schedd_fqdn}

      COLLECTOR_NAME = $(FULL_HOSTNAME)
      
      START = TRUE

      SUSPEND = FALSE

      PREEMPT = FALSE

      KILL = FALSE

      DAEMON_LIST = MASTER, STARTD

      FILESYSTEM_DOMAIN = $(FULL_HOSTNAME)

      RANK = 0

      ENABLE_IPV6=TRUE
      NETWORK_INTERFACE=${facts['networking']['ip6']}
      PREFER_IPV4 = false
      use role:get_htcondor_execute
      | EOF
  }

  file {'/etc/condor/config.d/10-stash-plugin.config':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @("EOF")
      STASH_PLUGIN = $(LIBEXEC)/stash_plugin
      FILETRANSFER_PLUGINS = $(FILETRANSFER_PLUGINS),$(STASH_PLUGIN)
      | EOF
  }

  file { '/etc/condor/config.d/00-htcondor-9.0.config':
    ensure => absent,
  }

  file {'/etc/condor/password.d/':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0077',
  }

  exec { 'store_condor_password':
    command => 'condor_store_cred add -c -i -',
    stdin   => $schedd_password.unwrap,
    unless  => 'condor_store_cred query -c >/dev/null 2>&1',
  }

  file {'/etc/condor/tokens.d/':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0077',
  }

  exec { 'create_condor_token':
    command => "/bin/bash -c 'umask 0077; condor_token_create -identity condor@${schedd_fqdn} > /etc/condor/tokens.d/condor@${schedd_fqdn}'",
    creates => "/etc/condor/tokens.d/condor@${schedd_fqdn}",
    path    => ['/bin', '/usr/bin', '/usr/sbin', '/sbin'],
  }

  file { "/etc/condor/tokens.d/condor@${schedd_fqdn}":
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0600',
  }

  file {'/etc/condor/config.d/09-slots.config':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => 'puppet:///modules/condor/09-slots.config'
  }

  file {'/etc/condor/condor_config':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0600',
    source => 'puppet:///modules/condor/condor_config'
  }

  file {$scratch_directory:
    ensure => 'directory',
    owner  =>  'condor',
    group  => 'condor',
    mode   => '0755'
  }

  file { '/usr/lib64/condor/condor_ssh_to_job_sshd_config_template':
    ensure => 'link',
    target => '/etc/condor/condor_ssh_to_job_sshd_config_template',
  }

  service {'condor':
    ensure => running,
    enable => true
  }
}
