#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>

void pass_connection(const char *ip, int port)
{
	int socket_fd = socket(PF_INET, SOCK_STREAM, 0);

	struct sockaddr_in address;
	address.sin_family = AF_INET;
	address.sin_addr.s_addr = inet_addr(ip);
	address.sin_port = htons(port);
	memset(address.sin_zero, '\0', sizeof(address.sin_zero));

	connect(socket_fd, (struct sockaddr *) &address, sizeof(address));

	char buf[1] = { '\0' };

	struct iovec iov[1];
	iov[0].iov_base = buf;
	iov[0].iov_len = 1;

	struct cmsghdr cmsg;
	cmsg.cmsg_level = SOL_SOCKET;
	cmsg.cmsg_type = SCM_RIGHTS;
	cmsg.cmsg_len = CMSG_LEN(sizeof(socket_fd));
	*(int *)CMSG_DATA(&cmsg) = socket_fd;

	struct msghdr msg;
	msg.msg_name = NULL;
	msg.msg_namelen = 0;
	msg.msg_iov = iov;
	msg.msg_iovlen = 1;
	msg.msg_control = &cmsg;
	msg.msg_controllen = cmsg.cmsg_len;

	ssize_t result = sendmsg(STDOUT_FILENO, &msg, 0);
	assert(result == 1);
}
