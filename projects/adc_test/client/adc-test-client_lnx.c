#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h> 

void error(const char *msg)
{
	perror(msg);
	exit(0);
}

int main(int argc, char *argv[])
{
	int sockfd, portno, n, i;
	struct sockaddr_in serv_addr;
	struct hostent *server;
	int bytesReceived=0;

	//char buffer[256];
	int32_t buffer[256*4096];
	//int32_t bufferIn[256];
  float bufferOut[256*4096];

	if (argc < 3) {
		fprintf(stderr,"usage %s hostname port\n", argv[0]);
		exit(0);
	}
	portno = atoi(argv[2]);
	sockfd = socket(AF_INET, SOCK_STREAM, 0);
	if (sockfd < 0) 
		error("ERROR opening socket");
	server = gethostbyname(argv[1]);
	if (server == NULL) {
		fprintf(stderr,"ERROR, no such host\n");
		exit(0);
	}
	bzero((char *) &serv_addr, sizeof(serv_addr));
	serv_addr.sin_family = AF_INET;
	bcopy((char *)server->h_addr, 
			(char *)&serv_addr.sin_addr.s_addr,
			server->h_length);
	serv_addr.sin_port = htons(portno);
	if(connect(sockfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0)
	{
		perror("connect");
		return 1;
	}

//	while(1)
//  {
//    bytesReceived=recv(sockfd, buffer, 256*4096, MSG_WAITALL);
//    for(i = 0; i < bytesReceived; ++i)
//    {
//      bufferOut[i] = ((float)buffer[i]) / 2147483647.0;
//    }
//    //printf("%f\n",*bufferOut);
//    //printf(bufferOut);
//
//    fwrite(bufferOut, 1, 256*4096, stdout);
//    fflush(stdout);
//  }

	do
    {
        bytesReceived = recv(
                sockfd,
                buffer,
                256*4096,
                MSG_WAITALL);

        for (i = 0; i < bytesReceived; ++i)
            printf("%f\n", (float)buffer[i]/2147483647.0);
    }
    while(bytesReceived);

	//while(1)
	//{
		//recv(sockfd, buffer, 256*4096, MSG_WAITALL);
	//	n=read(sockfd,buffer,256*4096);
	//	printf("%s\n",buffer);
	//}

	//    if (connect(sockfd,(struct sockaddr *) &serv_addr,sizeof(serv_addr)) < 0) 
	//        error("ERROR connecting");
	//    printf("Please enter the message: ");
	//    bzero(buffer,256);
	//    fgets(buffer,255,stdin);
	//    n = write(sockfd,buffer,strlen(buffer));
	//    if (n < 0) 
	//         error("ERROR writing to socket");
	//    bzero(buffer,256);
	//    n = read(sockfd,buffer,255);
	//    if (n < 0) 
	//         error("ERROR reading from socket");
	//    printf("%s\n",buffer);
	close(sockfd);
	return 0;
}
