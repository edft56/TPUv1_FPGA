#include <verilated.h>          // Defines common routines
#include <iostream>             // Need std::cout
#include "Vmain.h"               // From Verilating "top.v"
#include "verilated_vcd_c.h"
#include "Vmain_main.h"
#include "Vmain_accumulator.h"
#include <iomanip>
#include <fstream>

#include <cmath>
#include <bitset>

const bool trace = true;

const uint32_t V_DIM = 64; 
const uint32_t U_DIM = 64; 
const uint32_t ITER_DIM = 64; 

void matrix_multiply(uint32_t* V_matrix, uint32_t* U_matrix, uint32_t* out_matrix, uint32_t V_DIM, uint32_t U_DIM, uint32_t ITER_DIM ){
    for(int i=0; i<ITER_DIM; i++){
        for(int j=0; j<V_DIM; j++){
            for(int k=0; k<U_DIM; k++){
                out_matrix[j*U_DIM + k] += V_matrix[j*ITER_DIM + i] * U_matrix[i*U_DIM + k];
            }
        }
    }
}

void clock_tick(Vmain* top, vluint64_t& time, VerilatedVcdC* tfp){
    top->clk_i ^= 1;
    top->eval();
    if (trace) tfp->dump(time);
    time++;
}

void handle_inputs(Vmain* top, uint64_t& positive_edges, uint32_t* U_matrix, uint32_t ITER_DIM, uint32_t U_DIM){
    static int tile_x = 0;
    static int tile_y = 0;
    static int col = 0;

    if (positive_edges>2 && top->request_fifo_data_o){
        top->sending_fifo_data_i = 1;

        for(int i=0; i<32; i++){
            top->weight_fifo_data_in[i] = U_matrix[tile_y*32*U_DIM + i*U_DIM + tile_x*32 + col];
            //top->weight_fifo_data_in[i] = 1;
        }
        bool tile_y_up = ((col+1) % (32) == 0);
        bool tile_x_up = (tile_y == (ITER_DIM/32)-1) && tile_y_up;
        col = (col+1) % (32);
        tile_y = ( tile_y == (ITER_DIM/32)-1 && tile_y_up ) ? 0 : ( tile_y_up ? tile_y + 1 : tile_y );
        tile_x = ( tile_x == (U_DIM/32)-1 && tile_x_up) ? 0 : ( tile_x_up ? tile_x + 1 : tile_x );

    }
}

void generate_inputs(uint32_t* V_matrix, uint32_t* U_matrix, uint32_t V_DIM, uint32_t U_DIM, uint32_t ITER_DIM ){
    std::ofstream OutFile;
    OutFile.open("V_matrix.dat", std::ios::out | std::ios::binary);

    for(int i=0; i<V_DIM; i++){
        for(int j=0; j<ITER_DIM; j++){
            //V_matrix[i*ITER_DIM + j] = 1;
            V_matrix[i*ITER_DIM + j] = (j)%4;
            OutFile << V_matrix[i*ITER_DIM + j] <<std::endl;
        }
    }
    OutFile.close();

    for(int i=0; i<ITER_DIM; i++){
        for(int j=0; j<U_DIM; j++){
            U_matrix[i*U_DIM + j] = 1;
            //U_matrix[i*U_DIM + j] = j;
        }
    }
}



void simulate_DUT(uint32_t* U_matrix,uint32_t U_DIM, uint32_t ITER_DIM){
    Vmain* top = new Vmain;

    vluint64_t sim_time = 800;
    
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    if (trace){
        top->trace(tfp, 99);  // Trace 99 levels of hierarchy
        tfp->open("top_sim.vcd");
    }


    vluint64_t time = 0;
    uint64_t positive_edges = 0;


    top->clk_i = 0;
    top->rst_i = 0;
    top->instruction_i = 0;
    top->H_DIM_i = 63;
    top->W_DIM_i = 63;

    for(int i=0; i<32; i++){
        top->weight_fifo_data_in[i] = 1;
    }

    top->eval();            // Evaluate model
    if (trace) tfp->dump(time*2);
    
    for(uint i=0; i<sim_time; i++){ //
        handle_inputs(top,positive_edges,U_matrix,ITER_DIM,U_DIM);
        top->instruction_i = 1;

        clock_tick(top,time,tfp);
        positive_edges++;

        clock_tick(top,time,tfp);
        
        if(top->done_o==1) break;
    }

    
    top->final();               // Done simulating

    //std::cout<<(unsigned char)(top->main->accum->__PVT__port2_wr_en_i);
    std::cout<<"\n";
    for(int i=0; i<128; i++){
        std::cout<<std::setw(3)<<i<<": ";
        for(int j=0; j<32; j++){
            std::cout<<(uint32_t)(top->main->accum->accumulator_storage[i][j])<<" ";
        }
        std::cout<<"\n";
    }
    
    //std::cout<<(top->H_DIM_i);

    delete top;
    
    if (trace)tfp->close();
}



int main() {
    uint32_t* V_matrix = (uint32_t*) malloc(V_DIM*ITER_DIM*sizeof(uint32_t));
    uint32_t* U_matrix = (uint32_t*) malloc(U_DIM*ITER_DIM*sizeof(uint32_t));
    uint32_t* out_matrix = (uint32_t*) calloc(V_DIM*U_DIM,sizeof(uint32_t));

    generate_inputs(V_matrix,U_matrix,V_DIM,U_DIM,ITER_DIM);
    matrix_multiply(V_matrix,U_matrix,out_matrix,V_DIM,U_DIM,ITER_DIM);
    for(int i=0; i<V_DIM; i++){
        for(int j=0; j<U_DIM; j++){
            std::cout<<out_matrix[i*U_DIM + j]<<" ";
        }
        std::cout<<"\n";
    }
    std::cout<<"\n";

    // for(int i=0; i<V_DIM; i++){
    //     for(int j=0; j<ITER_DIM; j++){
    //         std::cout<<V_matrix[i*V_DIM + j]<<" ";
    //     }
    //     std::cout<<"\n";
    // }
    // std::cout<<"\n";

    simulate_DUT(U_matrix,U_DIM,ITER_DIM);    

    return 0;
}