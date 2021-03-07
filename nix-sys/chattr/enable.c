#include <linux/fs.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <fcntl.h>

static int fssetflags(int fd, unsigned int flags)
{
	return ioctl(fd, FS_IOC_SETFLAGS, (void*)&flags);
}

static int path_setattrs(const char *path, unsigned int flags)
{
	int fd;
	int err;

	fd = open(path, O_NONBLOCK|O_RDONLY);
	if (fd < 0)
		return 1;
	err = fssetflags(fd, flags);
	close(fd);

	return err;
}

int immutable_on(const char *path)
{
	return path_setattrs(path, FS_IMMUTABLE_FL);
}

int immutable_off(const char *path)
{
	return path_setattrs(path, 0);
}
