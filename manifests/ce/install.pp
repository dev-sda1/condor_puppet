# @summary A short summary of the purpose of this class
#
# Configures HTCondor on a CE that runs ARC-CE. Note that this configures Condor to be both a central manager AND submit node!
#
# @example
#   include condor::ce::install
class condor::ce::install(
  String $supported_vos = 'cms lhcb atlas dune gridpp ops',
  Sensitive $schedd_password = '',
  $scratch_directory = '/scratch'
) {
  $_split_vos = $supported_vos.split(' ')
  class {'condor::usermaps':
    vos_supported => $_split_vos
  }

  file {'/etc/condor/config.d/01-central-manager.config':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @("EOF")
      CONDOR_HOST = ${facts['networking']['fqdn']}

      COLLECTOR_NAME = $(FULL_HOSTNAME)

      IN_HIGHPORT = 25000
      IN_LOWPORT = 21000
      
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

      EXECUTE = ${scratch_directory}

      STARTER_ALLOW_RUNAS_OWNER = TRUE
      use role:get_htcondor_central_manager
      use role:get_htcondor_submit
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
    command => "/bin/bash -c 'umask 0077; condor_token_create -identity condor@${facts['networking']['fqdn']} > /etc/condor/tokens.d/condor@${facts['networking']['fqdn']}'",
    creates => "/etc/condor/tokens.d/condor@${facts['networking']['fqdn']}",
    path    => ['/bin', '/usr/bin', '/usr/sbin', '/sbin'],
  }

  file { "/etc/condor/tokens.d/condor@${facts['networking']['fqdn']}":
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0600',
  }


  service {'firewalld':
    ensure => 'stopped',
    enable => false
  }

  file {'/etc/condor/condor_config':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0600',
    source => 'puppet:///modules/condor/condor_config'
  }

  file { '/usr/lib64/condor/condor_ssh_to_job_sshd_config_template':
    ensure => 'link',
    target => '/etc/condor/condor_ssh_to_job_sshd_config_template',
  }

  file { $scratch_directory:
    ensure => 'directory',
    owner  =>  'condor',
    group  => 'condor',
    mode   => '0755'
  }

  service {'condor':
    ensure => running,
    enable => true
  }
}
