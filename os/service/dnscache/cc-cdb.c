#include <cdb.h>
#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>
#include <unistd.h>

int main(int argc, char **argv)
{
	int line = 0;
	char buffer[512]; // should be enough for my needs.
	uint8_t ip[4];
	int ret;
	char *saveptr;
	char *ip_s;
	char *token;
	char c;
	int fd;
	int err;
	struct cdb_make cdbm;


	fd = open("hosts.cdb~", O_RDWR|O_CREAT, 0600);
	if (fd < 0) {
		perror("Failed to open `./hosts.cdb~' read-write.");
		return 1;
	}
	err = cdb_make_start(&cdbm, fd);
	if (err != 0) {
		perror("cdb_make_start() failed");
		close(fd);
		unlink("hosts.cdb~");
		return 1;
	}

	while (fgets(buffer, sizeof buffer, stdin)) {
		line += 1;
		if (*buffer == '\n' || *buffer == '\0' || *buffer == '#') {
			continue;
		}
		saveptr = NULL;
		ip_s = strtok_r(buffer, "\t ", &saveptr);
		ret = sscanf(ip_s, "%" SCNu8 ".%" SCNu8 ".%" SCNu8 ".%" SCNu8,
		             ip, ip + 1, ip + 2, ip + 3);
		if (ret != 4) {
			fprintf(stderr, "Failed to parse ip (line %d)\n", line);
			continue;
		}
		while ((token = strtok_r(NULL, "\t ", &saveptr))) {
			char *begin, *end;
			begin = token - 1;
			end = begin + 1;
			while (*end != ' ' && *end != '\n' && *end != '\0') {
				if (*end == '.') {
					*begin = end - begin - 1;
					begin = end;
				}
				end ++;
			}
			*begin = end - begin - 1;
			c = *end;
			*end = '\0';
			cdb_make_add(&cdbm, token - 1, end - token + 2, ip, 4);
			*end = c;
		}
	}
	err = cdb_make_finish(&cdbm);
	if (err != 0) {
		perror("cdb_make_finish() failed");
		close(fd);
		unlink("hosts.cdb~");
		return 1;
	}
	err = close(fd);
	if (err != 0) {
		perror("close() failed");
		unlink("hosts.cdb~");
		return 1;
	}
	err = rename("hosts.cdb~", "hosts.cdb");
	if (err != 0) {
		perror("rename() failed");
		unlink("hosts.cdb~");
	}
	return 0;
}
