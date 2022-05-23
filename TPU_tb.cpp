#include <verilated.h>          // Defines common routines
#include <iostream>             // Need std::cout
#include "Vmain.h"               // From Verilating "top.v"
#include "verilated_vcd_c.h"


#include <cmath>
#include <bitset>

const bool trace = true;

void simulate_DUT(){
    Vmain* top = new Vmain;

    vluint64_t sim_time = 400;

    uint8_t weight_data_in[32] = {1};
    
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    if (trace){
        top->trace(tfp, 99);  // Trace 99 levels of hierarchy
        tfp->open("top_sim.vcd");
    }


    vluint64_t time = 0;
    top->clk_i = 0;
    top->rst_i = 0;
    top->instruction_i = 0;
    for(int i=0; i<32; i++){
        top->weight_fifo_data_in[i] = 1;
    }
    
    for(uint i=0; i<sim_time; i++){ //
        
        top->clk_i = 0;

        if(time>2) top->instruction_i = 1;

        top->eval();            // Evaluate model
        if (trace) tfp->dump(time*2);

        top->clk_i = 1;

        top->eval();            // Evaluate model
        if (trace) tfp->dump(time*2 + 1);
        
        time++;
    }

    
    top->final();               // Done simulating

    
    delete top;

    if (trace)tfp->close();
}



int main() {
    simulate_DUT();    

    return 0;
}