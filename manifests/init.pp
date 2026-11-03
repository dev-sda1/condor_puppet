#
# This is the main entry point for the condor class
#
class condor(
  $use_official_repo = false,
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
}
