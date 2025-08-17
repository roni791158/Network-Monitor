#include "netmon.h"
#include <sys/ioctl.h>
#include <net/if.h>
#include <ifaddrs.h>
#include <netdb.h>

static struct nfq_handle *h;
static struct nfq_q_handle *qh;

// Packet callback function
static int cb(struct nfq_q_handle *qh, struct nfgenmsg *nfmsg,
              struct nfq_data *nfa, void *data) {
    struct nfqnl_msg_packet_hdr *ph;
    struct nfqnl_msg_packet_hw *hwph;
    u_int32_t id = 0;
    unsigned char *payload;
    int payload_len;
    
    ph = nfq_get_msg_packet_hdr(nfa);
    if (ph) {
        id = ntohl(ph->packet_id);
    }
    
    hwph = nfq_get_packet_hw(nfa);
    payload_len = nfq_get_payload(nfa, &payload);
    
    if (payload_len >= 0) {
        // Parse IP header
        if (payload_len >= 20) {
            struct iphdr {
                unsigned int ihl:4;
                unsigned int version:4;
                unsigned char tos;
                unsigned short tot_len;
                unsigned short id;
                unsigned short frag_off;
                unsigned char ttl;
                unsigned char protocol;
                unsigned short check;
                unsigned int saddr;
                unsigned int daddr;
            } *iph = (struct iphdr*)payload;
            
            char src_ip[16], dst_ip[16];
            struct in_addr addr;
            
            addr.s_addr = iph->saddr;
            strcpy(src_ip, inet_ntoa(addr));
            
            addr.s_addr = iph->daddr;
            strcpy(dst_ip, inet_ntoa(addr));
            
            // Create traffic record
            traffic_record_t record;
            strncpy(record.ip, src_ip, MAX_IP_LEN - 1);
            record.url[0] = '\0'; // Will be filled by HTTP parsing
            record.timestamp = time(NULL);
            record.bytes_sent = ntohs(iph->tot_len);
            record.bytes_received = 0;
            
            // Parse HTTP if it's TCP on port 80 or 443
            if (iph->protocol == 6 && payload_len > 40) { // TCP
                unsigned char *tcp_payload = payload + (iph->ihl * 4) + 20;
                int tcp_payload_len = payload_len - (iph->ihl * 4) - 20;
                
                if (tcp_payload_len > 0) {
                    // Look for HTTP Host header
                    char *host_start = strstr((char*)tcp_payload, "Host: ");
                    if (host_start) {
                        host_start += 6; // Skip "Host: "
                        char *host_end = strstr(host_start, "\r\n");
                        if (host_end) {
                            int host_len = host_end - host_start;
                            if (host_len < MAX_URL_LEN - 1) {
                                strncpy(record.url, host_start, host_len);
                                record.url[host_len] = '\0';
                            }
                        }
                    }
                }
            }
            
            add_traffic_record(&record);
        }
    }
    
    return nfq_set_verdict(qh, id, NF_ACCEPT, 0, NULL);
}

int start_packet_capture(void) {
    printf("Opening library handle\n");
    h = nfq_open();
    if (!h) {
        fprintf(stderr, "Error during nfq_open()\n");
        return -1;
    }
    
    printf("Unbinding existing nf_queue handler for AF_INET (if any)\n");
    if (nfq_unbind_pf(h, AF_INET) < 0) {
        fprintf(stderr, "Error during nfq_unbind_pf()\n");
        return -1;
    }
    
    printf("Binding nfnetlink_queue as nf_queue handler for AF_INET\n");
    if (nfq_bind_pf(h, AF_INET) < 0) {
        fprintf(stderr, "Error during nfq_bind_pf()\n");
        return -1;
    }
    
    printf("Binding this socket to queue '0'\n");
    qh = nfq_create_queue(h, 0, &cb, NULL);
    if (!qh) {
        fprintf(stderr, "Error during nfq_create_queue()\n");
        return -1;
    }
    
    printf("Setting copy_packet mode\n");
    if (nfq_set_mode(qh, NFQNL_COPY_PACKET, 0xffff) < 0) {
        fprintf(stderr, "Can't set packet_copy mode\n");
        return -1;
    }
    
    return 0;
}

void stop_packet_capture(void) {
    if (qh) {
        printf("Unbinding from queue 0\n");
        nfq_destroy_queue(qh);
    }
    
    if (h) {
        printf("Closing library handle\n");
        nfq_close(h);
    }
}

int get_connected_devices(device_t **devices, int *count) {
    FILE *arp_file = fopen("/proc/net/arp", "r");
    if (!arp_file) {
        perror("Failed to open /proc/net/arp");
        return -1;
    }
    
    char line[256];
    *count = 0;
    
    // Count entries first
    fgets(line, sizeof(line), arp_file); // Skip header
    while (fgets(line, sizeof(line), arp_file)) {
        (*count)++;
    }
    
    if (*count == 0) {
        fclose(arp_file);
        *devices = NULL;
        return 0;
    }
    
    *devices = malloc(sizeof(device_t) * (*count));
    if (*devices == NULL) {
        fclose(arp_file);
        return -1;
    }
    
    rewind(arp_file);
    fgets(line, sizeof(line), arp_file); // Skip header again
    
    int i = 0;
    while (fgets(line, sizeof(line), arp_file) && i < *count) {
        char ip[MAX_IP_LEN], hw_type[10], flags[10], mac[MAX_MAC_LEN], mask[20], device[20];
        
        if (sscanf(line, "%s %s %s %s %s %s", ip, hw_type, flags, mac, mask, device) == 6) {
            strncpy((*devices)[i].ip, ip, MAX_IP_LEN - 1);
            (*devices)[i].ip[MAX_IP_LEN - 1] = '\0';
            
            strncpy((*devices)[i].mac, mac, MAX_MAC_LEN - 1);
            (*devices)[i].mac[MAX_MAC_LEN - 1] = '\0';
            
            // Try to resolve hostname
            char *hostname = resolve_hostname(ip);
            if (hostname) {
                strncpy((*devices)[i].hostname, hostname, MAX_HOSTNAME_LEN - 1);
                (*devices)[i].hostname[MAX_HOSTNAME_LEN - 1] = '\0';
                free(hostname);
            } else {
                strcpy((*devices)[i].hostname, "Unknown");
            }
            
            (*devices)[i].first_seen = time(NULL);
            (*devices)[i].last_seen = time(NULL);
            (*devices)[i].is_active = 1;
            
            i++;
        }
    }
    
    *count = i;
    fclose(arp_file);
    return 0;
}

char* resolve_hostname(const char *ip) {
    struct sockaddr_in sa;
    char *hostname = malloc(MAX_HOSTNAME_LEN);
    
    if (!hostname) return NULL;
    
    sa.sin_family = AF_INET;
    inet_pton(AF_INET, ip, &sa.sin_addr);
    
    if (getnameinfo((struct sockaddr*)&sa, sizeof(sa), hostname, MAX_HOSTNAME_LEN, NULL, 0, 0) != 0) {
        free(hostname);
        return NULL;
    }
    
    return hostname;
}

char* get_mac_address(const char *ip) {
    FILE *arp_file = fopen("/proc/net/arp", "r");
    if (!arp_file) return NULL;
    
    char line[256];
    char *mac = malloc(MAX_MAC_LEN);
    if (!mac) {
        fclose(arp_file);
        return NULL;
    }
    
    fgets(line, sizeof(line), arp_file); // Skip header
    
    while (fgets(line, sizeof(line), arp_file)) {
        char arp_ip[MAX_IP_LEN], hw_type[10], flags[10], arp_mac[MAX_MAC_LEN];
        
        if (sscanf(line, "%s %s %s %s", arp_ip, hw_type, flags, arp_mac) == 4) {
            if (strcmp(arp_ip, ip) == 0) {
                strncpy(mac, arp_mac, MAX_MAC_LEN - 1);
                mac[MAX_MAC_LEN - 1] = '\0';
                fclose(arp_file);
                return mac;
            }
        }
    }
    
    fclose(arp_file);
    free(mac);
    return NULL;
}
