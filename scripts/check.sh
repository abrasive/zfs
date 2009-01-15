#!/bin/bash

prog=check.sh
spl_module=../module/spl/spl.ko
splat_module=../module/splat/splat.ko
splat_cmd=../cmd/splat
verbose=

die() {
	echo "${prog}: $1" >&2
	exit 1
}

warn() {
	echo "${prog}: $1" >&2
}

if [ -n "$V" ]; then
	verbose="-v"
fi

if [ -n "$TESTS" ]; then
	tests="$TESTS"
else
	tests="-a"
fi

if [ $(id -u) != 0 ]; then
	die "Must run as root"
fi

if /sbin/lsmod | egrep -q "^spl|^splat"; then
	die "Must start with spl modules unloaded"
fi

if [ ! -f ${spl_module} ] || [ ! -f ${splat_module} ]; then
	die "Source tree must be built, run 'make'"
fi

spl_module_params="spl_debug_mask=-1 spl_debug_subsys=-1"
echo "Loading ${spl_module}"
/sbin/insmod ${spl_module} ${spl_module_params} || die "Failed to load ${spl_module}"

echo "Loading ${splat_module}"
/sbin/insmod ${splat_module} || die "Unable to load ${splat_module}"

# Wait a maximum of 3 seconds for udev to detect the new splatctl 
# device, if we do not see the character device file created assume
# udev is not running and manually create the character device.
for i in `seq 1 50`; do
	sleep 0.1

	if [ -c /dev/splatctl ]; then
		break
	fi

	if [ $i -eq 50 ]; then
		mknod /dev/splatctl c 229 0
	fi
done

$splat_cmd $tests $verbose

echo "Unloading ${splat_module}"
/sbin/rmmod ${splat_module} || die "Failed to unload ${splat_module}"

echo "Unloading ${spl_module}"
/sbin/rmmod ${spl_module} || die "Unable to unload ${spl_module}"

exit 0
