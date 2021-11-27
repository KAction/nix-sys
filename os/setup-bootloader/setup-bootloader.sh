#!@busybox@/bin/sh -eu
export PATH=@path@
syslinux=@syslinux@
out=$1
kernel=$2
init=$3

# By design, nix-sys removes files from previous config. We don't want it to
# happen with kernels, so this have to be done imperatively.
kernel_sha256=$(echo "$kernel"| cut -b11-32)
kernel_by_hash="/boot/kernel/hash/${kernel_sha256}"

# Storing kernel by its hash (well, output hash) and hard-linking
# kernel afterward saves storage on /boot partition which is
# usually quite small (e.g Alpine linux dedicates merely 90Mb to it).
if ! test -f "$kernel_by_hash" ; then
	mkdir -p "/boot/kernel/hash"
	cp "$kernel" "$kernel_by_hash"
fi

# Now, for every new invocation of nix-sys, we create new entry
# in bootloader, while taking care that two consequent calls to
# nix-sys (with same output hash) do not create duplicate entries.
current="none"
if test -r /boot/current ; then
	current=$(cat /boot/current)
fi

if test "$current" != "$out" ; then
	epoch=$(date +%s)
	now=$(date -d @$epoch +%Y-%m-%d.%s)
	base="/boot/kernel/conf/$now"

	mkdir -p "$base"
	ln "${kernel_by_hash}" "$base/image"
	ln -sf "$out" "$base/nix-sys.gc"
	nix-store --add-root "$base/nix-sys.gc" -r
	cat <<- EOF > "$base/extlinux.conf"
	LABEL $now
	    LINUX /kernel/conf/$now/image
	    APPEND root=/dev/sda3 init=$init nix-sys=$out
	EOF
fi

# Even if there are no new configurations, we must regenerate
# extlinux.conf, since user may have deleted old generations
# manually to save disk space.
mkdir -p /boot/extlinux
config=/boot/extlinux/extlinux.conf

cat << EOF > "$config~"
DEFAULT menu.c32
MENU TITLE nix-sys boot menu
EOF

for x in $(ls -d /boot/kernel/conf/* | tac); do
	if test -f "$x/extlinux.conf" ; then
		cat "$x/extlinux.conf"
	else  # backward compatibility with age of lilo
		append=$(grep 'append =' "$x/lilo.conf"| tr -d '"'|sed 's/append =//')
		name=${x##*/}
		cat <<- EOF
		LABEL $name
		    LINUX /kernel/conf/$name/image
		    APPEND root=/dev/sda3 $append
		EOF
	fi
done >> "$config~"

if ! cmp -s "$config" "$config~" ; then
	mv "$config~" "$config"

	# 440 bytes are not much, but still let's try to avoid unneeded IO.
	if ! test -f /boot/extlinux/.mbr ; then
		dd if="$syslinux"/share/syslinux/mbr.bin of=/dev/sda bs=440 count=1
		touch /boot/extlinux/.mbr
		extlinux -i /boot/extlinux
	fi

	for name in menu libutil ; do
		src="$syslinux/share/syslinux/$name.c32"
		dst="/boot/extlinux/$name.c32"
		if ! test -f "$dst" ; then
			cp "$src" "$dst"
		fi
	done
fi

rm -f "$config~"
echo "$out" > /boot/current
