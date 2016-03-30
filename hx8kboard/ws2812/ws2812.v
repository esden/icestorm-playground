////////////////////////////////////////
// Driver for WS2812-based LED strips //
////////////////////////////////////////

module ws2812
  #(
    parameter NUM_LEDS          = 64,          // The number of LEDS in the chain
    parameter SYSTEM_CLOCK      = 12_000_000 // The frequency of the input clock signal, in Hz. This value must be correct in order to have correct timing for the WS2812 protocol.
    )
   (
    input                              clk,          // Clock input.
    input                              reset,        // Resets the internal state of the driver

    /////////////////////
    // Control signals //
    /////////////////////
    output                             data_request, // This signal is asserted one cycle before red_in, green_in, and blue_in are sampled.
    output                             new_address,  // This signal is asserted whenever the address signal is updated to its new value.
    output [LED_ADDRESS_WIDTH-1:0] address,      // The current LED number. This signal is incremented to the next value two cycles after the last time data_request was asserted.
    
    input [7:0]                        red_in,       // 8-bit red data
    input [7:0]                        green_in,     // 8-bit green data
    input [7:0]                        blue_in,      // 8-bit blue data
    
    ////////////////////
    // External ports //
    ////////////////////
    output                         DO            // Signal to send to WS2812 chain.
    );
   
   function integer log2;
      input integer                    value;
      begin
         value = value-1;
         for (log2=0; value>0; log2=log2+1)
           value = value>>1;
      end
   endfunction
	
   localparam integer LED_ADDRESS_WIDTH = log2(NUM_LEDS);         // Number of bits to use for address input

   /////////////////////////////////////////////////////////////
   // Timing parameters for the WS2812                        //
   // The LEDs are reset by driving D0 low for at least 50us. //
   // Data is transmitted using a 800kHz signal.              //
   // A '1' is 50% duty cycle, a '0' is 20% duty cycle.       //
   /////////////////////////////////////////////////////////////
   localparam integer CYCLE_COUNT         = SYSTEM_CLOCK / 800000;
   localparam integer H0_CYCLE_COUNT      = 0.32 * CYCLE_COUNT;
   localparam integer H1_CYCLE_COUNT      = 0.64 * CYCLE_COUNT;
   localparam integer CLOCK_DIV_WIDTH     = log2(CYCLE_COUNT);
   
   localparam integer RESET_COUNT         = 100 * CYCLE_COUNT;
   localparam integer RESET_COUNTER_WIDTH = log2(RESET_COUNT);

   reg [CLOCK_DIV_WIDTH-1:0]             clock_div;           // Clock divider for a cycle
   reg [RESET_COUNTER_WIDTH-1:0]         reset_counter;       // Counter for a reset cycle
   
   localparam STATE_RESET    = 3'd0;
   localparam STATE_LATCH    = 3'd1;
   localparam STATE_PRE      = 3'd2;
   localparam STATE_TRANSMIT = 3'd3;
   localparam STATE_POST     = 3'd4;
   reg [2:0]                           state;              // FSM state

   localparam COLOR_G     = 2'd0;
   localparam COLOR_R     = 2'd1;
   localparam COLOR_B     = 2'd2;
   reg [1:0]                           color;              // Current color being transferred
                          
   reg [7:0]                           red;
   reg [7:0]                           green;
   reg [7:0]                           blue;
   
   reg [7:0]                           current_byte;       // Current byte to send
   reg [2:0]                           current_bit;        // Current bit index to send

   wire                                reset_almost_done;
   wire                                led_almost_done;

   assign reset_almost_done = (state == STATE_RESET) && (reset_counter == RESET_COUNT-1);
   assign led_almost_done   = (state == STATE_POST)  && (color == COLOR_B) && (current_bit == 0) && (address != 0);

   assign data_request = reset_almost_done || led_almost_done;
   assign new_address  = (state == STATE_PRE) && (current_bit == 7);
   
   always @ (posedge clk) begin
      if (reset) begin
         address <= 0;
         state <= STATE_RESET;
         DO <= 0;
         reset_counter <= 0;
         color <= COLOR_G;
         current_bit <= 7;
      end
      else begin
         case (state)
           STATE_RESET: begin
              // De-assert DO, and wait for 75 us.
              DO <= 0;
              if (reset_counter == RESET_COUNT-1) begin
                 reset_counter <= 0;
                 state <= STATE_LATCH;
              end
              else begin
                 reset_counter <= reset_counter + 1;
              end
           end // case: STATE_RESET
           STATE_LATCH: begin
              // Latch the input
              red <= red_in;
//              green <= green_in;
              blue <= blue_in;

              // Setup the new address
              address <= address + 1;
              
              // Start sending green
              color <= COLOR_G;
              current_byte <= green_in;
              current_bit <= 7;
              
              state <= STATE_PRE;
           end
           STATE_PRE: begin
              // Assert DO, start clock divider counter
              clock_div <= 0;
              DO <= 1;
              state <= STATE_TRANSMIT;
           end
           STATE_TRANSMIT: begin
              // De-assert DO after a certain amount of time, depending on if you're transmitting a 1 or 0.
              if (current_byte[7] == 0 && clock_div >= H0_CYCLE_COUNT) begin
                 DO <= 0;
              end
              else if (current_byte[7] == 1 && clock_div >= H1_CYCLE_COUNT) begin
                 DO <= 0;
              end
              // Advance cycle counter
              if (clock_div == CYCLE_COUNT-1) begin
                 state <= STATE_POST;
              end
              else begin
                 clock_div <= clock_div + 1;
              end
           end
           STATE_POST: begin
              if (current_bit != 0) begin
                 // Start sending next bit of data
                 current_byte <= {current_byte[6:0], 1'b0};
                 case (current_bit)
                    7: current_bit <= 6;
                    6: current_bit <= 5;
                    5: current_bit <= 4;
                    4: current_bit <= 3;
                    3: current_bit <= 2;
                    2: current_bit <= 1;
                    1: current_bit <= 0;
                 endcase
                 state <= STATE_PRE;
              end
              else begin
                 // Advance to the next color. If we were on blue, advance to the next LED
                 case (color)
                    COLOR_G: begin
                       color <= COLOR_R;
                       current_byte <= red;
                       current_bit <= 7;
                       state <= STATE_PRE;
                    end
                   COLOR_R: begin
                      color <= COLOR_B;
                      current_byte <= blue;
                      current_bit <= 7;
                      state <= STATE_PRE;
                   end
                   COLOR_B: begin
                      // If we were on the last LED, send out reset pulse
                      if (address == 0) begin
                         state <= STATE_RESET;
                      end
                      else begin
                         state <= STATE_LATCH;
                      end
                   end
                 endcase // case (color)
              end
           end
         endcase
      end
   end
   
endmodule

module top (
  input  clk,
  input uart_rx,
  output uart_tx,
  input uart_rts,
  output uart_cts,
  output [7:0]LED,
  output ws_do
);


wire ws_data_out;
reg reset = 1;
reg [15:0] inc_counter = 1;
reg inc_dir = 0;
wire data_request;
wire new_address;
wire [1:0] address;
reg red_dir = 1;
reg [7:0] red = 0;
reg [7:0] green = 0;
reg [7:0] blue = 0;


ws2812 WS(.clk(clk),
       .reset(reset),
       .data_request(data_request),
       .new_address(new_address),
       .address(address),
       .red_in(red), .green_in(green), .blue_in(blue), .DO(ws_data_out));

always @(posedge clk) begin

  /* Reset the ws2812 generator. */
  if (reset) reset <= 0;

  /* Generate a continous fade. */
  /*
  if (data_request) 
    if (red_dir) begin
      if (red == 8'hFF) begin
        red_dir <= 0;
        red <= red - 8;
      end
      else red <= red + 8;
    end
    else begin
      if (red == 8'h00) begin
        red_dir <= 1;
        red <= red + 8;
      end
      else red <= red - 8;  
    end
  */

  /* Generate a ramp on red. */
  if (data_request)
    red <= red + 4;

  if (address == 0) begin
    inc_counter <= inc_counter + 1;
    if (inc_counter == 0) begin
      red <= red + 1;
      if (inc_dir) begin
        if (green == 8'hFF) inc_dir <= 0;
        else green <= green + 1;
      end
      else begin
        if (green == 8'h00) inc_dir <= 1;
        else green <= green - 1;
      end
    end
  end
  ws_do <= ws_data_out;
  LED <= address;
end

endmodule
