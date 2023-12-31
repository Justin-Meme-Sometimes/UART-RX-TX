/*
This is the from the original verilog inputs from the solution
module uart_rx 
  #(parameter CLKS_PER_BIT)
  (
   input        i_Clock,
   input        i_Rx_Serial,
   output       o_Rx_DV,
   output [7:0] o_Rx_Byte
   );
    
  parameter s_IDLE         = 3'b000;
  parameter s_RX_START_BIT = 3'b001;
  parameter s_RX_DATA_BITS = 3'b010;
  parameter s_RX_STOP_BIT  = 3'b011;
  parameter s_CLEANUP      = 3'b100;
   
  reg           r_Rx_Data_R = 1'b1;
  reg           r_Rx_Data   = 1'b1;
   
  reg [7:0]     r_Clock_Count = 0;
  reg [2:0]     r_Bit_Index   = 0; //8 bits total
  reg [7:0]     r_Rx_Byte     = 0;
  reg           r_Rx_DV       = 0;
  reg [2:0]     r_SM_Main     = 0;
*/

module UART_RX
    #(parameter clocks_per_bit)
    (input logic clock,
     input logic serial,
     input logic reset,
     output logic [7:0] message,
     output logic [3:0] BCD_OUT,
     output logic [3:0] BCD_OUT_2);    

   

    logic en_store_register, send_comm, en_counter, en_shift_reg,
        en_clock_counter,clear_clock_counter, clear_bit_count, end_comm,
        is_middle, end_of_cycle;

    logic [7:0] bitcount, shift_val, clock_value;

    Myfsm fsm (.*);

    //This is for shifting the original serial signal to the left each time
    //To get the message that we want to store
    ShiftRegisterSIPO #(8) serial_shift(.serial(serial), .en(en_shift_reg), 
        .clock(clock), .left('1), .Q(shift_val));

    //This reg is for the final output after the stop signal is asserted    
    Register #(8) final_output_reg (.D(shift_val), .en(end_comm) .clock(clock),
        .clear(en_store_reg) .Q(output_val));


    //This is a counter for counting the amount of bits the UART signal has
    //Already passed in the data reading phase
    Counter #(8) bit_counter (.D('0), .en(en_counter), .clock(clock), .UP('1), 
        .load(0), .Q(bit_count), .clear(clear_bit_count));

    //This counter counts the clock cycles
    Counter #(8) clock_counter (.D('0), .en(en_clock_counter), .clock(clock), 
        .UP('1), .load(0), .Q(clock_value), .clear(end_of_cycle));

    //This checks for if the dataphase is over
    logic 
    alwayscomb begin
        end_comm = (bitcount == 8'd8);
        end_of_cycle = (clock_value == clocks_per_bit-1);
        //This checks the middle of a bit to find out whether the bit is 1 or 0
        //This is important because UART checks what the signal is in the middle
        //of the bit.
        is_middle = clock_value == (clocks_per_bit >> 1);
    end
endmodule

module fsm
        (input logic serial,
         input logic reset,
         input logic is_middle, 
         output logic en_shift_reg,
         output logic clear_clock_counter,
         output logic clear_bit_count,
         output logic en_clock_counter,
         output logic end_comm,
         output logic en_store_register);


    enum{INIT,DATAPHASE,IN_STOP_BIT,SAMPLING} nextState, currentState; 

    always_ff (posedge clock, negedge reset) begin
        if(reset) begin
            nextState <= INIT;
        end else begin
            nextState <= currentState;
        end
    end


    always_comb begin
        case(current_state)
            clear_bit_count = '1;
            en_shift_reg = '0;
            en_clock_counter = '0;
            en_store_register = '0;
            INIT: begin
                if(serial) begin
                    clear_bit_count = '1;
                    en_shift_reg = '0;
                    en_clock_counter = '0;
                    en_store_register = '0;
                    nextState = INIT;
                end
                if(~serial) begin
                    clear_bit_count = '0;
                    en_shift_reg = '0;
                    en_clock_counter = '1;
                    en_store_register = '0;
                    nextState = STARTBIT;
                end
            end
            DATAPHASE: begin
                if(~is_middle && ~end_comm) begin
                    clear_bit_count = '0;
                    en_shift_reg = '0;
                    en_clock_counter = '1;
                    en_store_register = '0;
                    nextState = DATAPHASE;
                end
                if(is_middle && ~end_comm) begin
                    clear_bit_count = '0;
                    en_shift_reg = '1;
                    en_clock_counter = '1;
                    en_store_register = '0;
                    nextState = DATAPHASE;
                end
                if(end_comm) begin
                    clear_bit_count = '1;
                    en_shift_reg = '0;
                    en_clock_counter = '1;
                    en_store_register = '0;
                    nextState = IN_STOP_BIT;
                end
            end
            IN_STOP_BIT: begin
                if(~is_middle) begin
                    clear_bit_count = '0;
                    en_shift_reg = '0;
                    en_clock_counter = '1;
                    en_store_register = '0;
                    nextState = IN_STOP_BIT;
                end
                if(is_middle) begin
                    clear_bit_count = '0;
                    en_shift_reg = '0;
                    en_clock_counter = '1;
                    en_store_register = '1;
                    nextState = SAMPLING;
                end
            end

            SAMPLING: begin
                if(serial)begin
                    clear_bit_count = '0;
                    en_shift_reg = '0;
                    en_clock_counter = '0;
                    en_store_register = '0;
                    nextState = INIT;
                end
            end
        endcase

    end
endmodule
