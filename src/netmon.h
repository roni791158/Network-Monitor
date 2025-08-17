#ifndef NETMON_H
#define NETMON_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <linux/netfilter.h>
#include <libnetfilter_queue/libnetfilter_queue.h>
#include <libnetfilter_log/libnetfilter_log.h>
#include <json-c/json.h>
#include <sqlite3.h>

#define MAX_HOSTNAME_LEN 256
#define MAX_MAC_LEN 18
#define MAX_IP_LEN 16
#define MAX_URL_LEN 1024
#define MAX_QUERY_LEN 2048

typedef struct {
    char ip[MAX_IP_LEN];
    char mac[MAX_MAC_LEN];
    char hostname[MAX_HOSTNAME_LEN];
    time_t first_seen;
    time_t last_seen;
    int is_active;
} device_t;

typedef struct {
    char ip[MAX_IP_LEN];
    char url[MAX_URL_LEN];
    time_t timestamp;
    int bytes_sent;
    int bytes_received;
} traffic_record_t;

// Function prototypes
int init_database(void);
int add_device(device_t *device);
int update_device_activity(const char *ip, time_t timestamp);
int add_traffic_record(traffic_record_t *record);
int get_active_devices(device_t **devices, int *count);
int get_traffic_by_date(const char *start_date, const char *end_date, traffic_record_t **records, int *count);
void cleanup_database(void);

// Network utilities
int start_packet_capture(void);
void stop_packet_capture(void);
int get_connected_devices(device_t **devices, int *count);
char* resolve_hostname(const char *ip);
char* get_mac_address(const char *ip);

// Signal handlers
void signal_handler(int sig);

#endif // NETMON_H
