# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include condor::usermaps
class condor::usermaps(
  Array[String] $vos_supported,
  Hash[String, Integer] $vo_pools
) {
  $_enabled_vos = $vo_pools.filter |$vo, $base| {
    $vo in $vos_supported
  }

  $_enabled_vos.each |String $vo, Integer $base| {
    {
      '' => $base,
      'prd' => $base + 100,
      'prio' => $base + 200,
      'pil' => $base + 300,
      'sgm' => $base + 999,
    }.each |String $prefix, Integer $gid| {
      $groupname = "${vo}${prefix}"

      group {$groupname:
        ensure => present,
        gid    => $gid,
      }

      range(0, 9).each |Integer $i| {
        $username = sprintf('%s%s%03d', $prefix, $vo, $i)

        user { $username:
          ensure => present,
          gid    => $gid,
          home   => '',
          shell  => '/sbin/nologin'
        }
      }
    }
  }
}
