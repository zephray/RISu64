//
// RISu64 simulator
// Copyright 2022 Wenting Zhang
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
#include <stdio.h>
#include <stdint.h>
#include <assert.h>
#include <time.h>

#include "verilated.h"
#include "verilated_vcd_c.h"
#include "Vsimtop.h"
#include "Vsimtop___024root.h"

#include "klmemsim.h"
#include "earliercon.h"

#define RAM_BASE 0x80000000
#define RAM_SIZE 64*1024

#define CON_BASE 0x20000000

// Verilator related
Vsimtop *core;
VerilatedVcdC *trace;
uint64_t tickcount;

// Settings
bool enable_trace = false;
bool unlimited = true;
bool verbose = false;
uint64_t max_cycles;

KLMemsim *ram;
Earliercon *earliercon;

#define CONCAT(a,b) a##b
#define SIGNAL(x) CONCAT(core->rootp->simtop__DOT__asictop__DOT__risu__DOT__cpu__DOT__,x)

void tick() {
    // Software simulated parts should read the signal
    // before clock edge (simulate the combinational
    // path), but only put the data out after the
    // clock edge (DFF)

    // Note: accessing not mapped address causes deadlock
    uint8_t bus_req_ready = core->bus_req_ready;
    uint64_t bus_resp_rdata = core->bus_resp_rdata;
    uint8_t bus_resp_ren = core->bus_resp_ren;
    uint8_t bus_resp_size = core->bus_resp_size;
    uint8_t bus_resp_dstid = core->bus_resp_dstid;
    uint8_t bus_resp_valid = core->bus_resp_valid;

    ram->apply(
        core->bus_req_addr,
        core->bus_req_wen,
        core->bus_req_wdata,
        core->bus_req_wmask,
        core->bus_req_size,
        core->bus_req_srcid,
        core->bus_req_valid,
        bus_req_ready,
        bus_resp_rdata,
        bus_resp_ren,
        bus_resp_size,
        bus_resp_dstid,
        bus_resp_valid,
        core->bus_resp_ready
    );
    /*earliercon->apply(
        core->dm_addr,
        dm_rdata,
        core->dm_wdata,
        core->dm_wmask,
        core->dm_wen,
        core->dm_valid,
        dm_ready
    );*/

    core->clk = 1;
    core->eval();

    core->bus_req_ready = bus_req_ready;
    core->bus_resp_rdata = bus_resp_rdata;
    core->bus_resp_ren = bus_resp_ren;
    core->bus_resp_size = bus_resp_size;
    core->bus_resp_dstid = bus_resp_dstid;
    core->bus_resp_valid = bus_resp_valid;

    // Let combinational changes propagate
    core->eval();

    if (enable_trace)
        trace->dump(tickcount * 10000);
    core->clk = 0;
    
    core->eval();
    if (enable_trace)
        trace->dump(tickcount * 10000 + 5000);

    tickcount++;
}

void reset() {
    core->rst = 0;
    tick();
    core->rst = 1;
    tick();
    tick();
    tick();
    core->rst = 0;
    ram->reset();
}

int main(int argc, char *argv[]) {
    // Initialize testbench
    Verilated::commandArgs(argc, argv);

    core = new Vsimtop;
    Verilated::traceEverOn(true);

    ram = new KLMemsim(RAM_BASE, RAM_SIZE);
    earliercon = new Earliercon(CON_BASE);

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0) {
            printf("RISu64 Simulator\n");
            printf("Available parameters:\n"); 
            printf("    --trace: Enable waveform trace\n"); 
            printf("    --ram <filename>: Preload RAM image file\n");
            printf("    --cycles <maxcycles>: Set simulation cycle limit\n");
            printf("    --ilat <cycles>: Instruction memory latency\n");
            printf("    --dlat <cycles>: Data memory latency\n");
            printf("    --verbose: Enable verbose output\n");
            exit(0);
        }
        else if (strcmp(argv[i], "--trace") == 0) {
            enable_trace = true;
        }
        else if (strcmp(argv[i], "--ram") == 0) {
            if (i == argc - 1) {
                fprintf(stderr, "Error: no RAM filename provided\n");
                exit(1);
            }
            else {
                ram->load_file(argv[i + 1]);
            }
        }
        else if (strcmp(argv[i], "--cycles") == 0) {
            if (i == argc - 1) {
                fprintf(stderr, "Error: no cycle limit number provided\n");
                exit(1);
            }
            else {
                unlimited = false;
                max_cycles = atoi(argv[i + 1]);
            }
        }
        /*else if (strcmp(argv[i], "--ilat") == 0) {
            if (i == argc - 1) {
                fprintf(stderr, "Error: no cycle number provided\n");
                exit(1);
            }
            else {
                ram_iport->set_latency(atoi(argv[i + 1]));
            }
        }
        else if (strcmp(argv[i], "--dlat") == 0) {
            if (i == argc - 1) {
                fprintf(stderr, "Error: no cycle number provided\n");
                exit(1);
            }
            else {
                ram_dport->set_latency(atoi(argv[i + 1]));
            }
        }*/
        else if (strcmp(argv[i], "--verbose") == 0) {
            ram->set_verbose(true);
            verbose = true;
        }
    }

    if (enable_trace) {
        trace = new VerilatedVcdC;
        core->trace(trace, 99);
        trace->open("trace.vcd");
    }

    // Start simulation
    if (verbose)
        printf("Simulation start.\n");

    clock_t time = clock();

    reset();

    bool running = true;
    while (running) {
        tick();
        
        if ((!unlimited) && (tickcount > max_cycles)) {
            break;
        }

        if (!SIGNAL(dec_ix_legal) && SIGNAL(dec_ix_valid)) {
            if (verbose)
                printf("Encountered illegal instruction\n");
            break;
        }
    }

    time = clock() - time;
    time /= (CLOCKS_PER_SEC / 1000);
    if (time == 0) time = 1;

    if (verbose) {
        printf("Simulation stopped after %ld cycles,\n"
                "average simulation speed: %ld kHz.\n",
                tickcount, tickcount / time);
        for (int i = 0; i < 31; i++) {
            printf("R%d = %016lx\n", i + 1, SIGNAL(rf__DOT__rf_array[i]));
        }
    }

    int retval;
    if ((SIGNAL(rf__DOT__rf_array[9]) == 0) &&
            (SIGNAL(rf__DOT__rf_array[16]) == 93)) {
        printf("Test passed\n");
        retval = 0;
    }
    else {
        printf("Test failed\n");
        retval = 1;
    }

    if (enable_trace) {
        trace->close();
    }

    delete ram;
    delete earliercon;

    return retval;
}