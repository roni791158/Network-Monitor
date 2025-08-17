#include "netmon.h"

static volatile int running = 1;

void signal_handler(int sig) {
    (void)sig;
    running = 0;
    printf("Shutting down network monitor...\n");
}

int main(int argc, char *argv[]) {
    printf("Starting Network Monitor v1.0.0\n");
    
    // Set up signal handlers
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    // Initialize database
    if (init_database() != 0) {
        fprintf(stderr, "Failed to initialize database\n");
        return 1;
    }
    
    // Start packet capture
    if (start_packet_capture() != 0) {
        fprintf(stderr, "Failed to start packet capture\n");
        cleanup_database();
        return 1;
    }
    
    printf("Network monitor started successfully\n");
    
    // Main monitoring loop
    while (running) {
        device_t *devices = NULL;
        int device_count = 0;
        
        // Get connected devices
        if (get_connected_devices(&devices, &device_count) == 0) {
            for (int i = 0; i < device_count; i++) {
                add_device(&devices[i]);
                update_device_activity(devices[i].ip, time(NULL));
            }
            free(devices);
        }
        
        sleep(60); // Update every minute
    }
    
    stop_packet_capture();
    cleanup_database();
    printf("Network monitor stopped\n");
    
    return 0;
}
