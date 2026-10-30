# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include condor::worker::install
class condor::worker::install(
  $supported_vos = 'cms lhcb atlas dune gridpp ops',
  $use_official_repo = false, ## If true this will use the HTCondor repo instead of downloading condor from EPEL.
  $schedd_fqdn = '',
  $disable_firewalld = false, ## If your setup uses border firewalls
  $configure_selinux = false, ## If your setup uses SELinux
) {
  $_wlcg_packages = ['apptainer', 'HEP_OSlibs', 'wlcg-iam*', 'wlcg-voms*', 'fetch-crl', 'bind-utils', 'java-latest-openjdk', 'wget', 'bc']

  package {'epel-release':
    ensure => installed,
  }

  exec { 'enable_crb_repo':
    command => '/usr/bin/dnf config-manager --set-enabled crb',
    unless  => '/usr/bin/dnf repolist enabled | /usr/bin/grep -qi "^crb"',
  }
}
