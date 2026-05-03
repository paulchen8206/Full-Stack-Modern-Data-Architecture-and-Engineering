package com.example.realtime;

import com.example.realtime.job.RealtimeTopology;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class RealtimeProcessorApplication implements CommandLineRunner {

    private final RealtimeTopology realtimeTopology;

    public RealtimeProcessorApplication(RealtimeTopology realtimeTopology) {
        this.realtimeTopology = realtimeTopology;
    }

    public static void main(String[] args) {
        SpringApplication.run(RealtimeProcessorApplication.class, args);
    }

    @Override
    public void run(String... args) throws Exception {
        realtimeTopology.start();
    }
}
