module top (
	input  clk,
  input uart_rx,
  output uart_tx,
  input uart_rts,
  output uart_cts,
	output [7:0]LED
);

/*
	localparam BITS = 8;
	localparam LOG2DELAY = 19;

	reg [BITS+LOG2DELAY-1:0] counter = 0;
	reg [BITS-1:0] outcnt;

	always@(posedge clk) begin
		counter <= counter + 1;
		outcnt <= counter >> LOG2DELAY;
	end

	assign {LED0, LED1, LED2, LED3, LED4, LED5, LED6, LED7} = outcnt;
*/

  wire RxD_data_ready;
  wire [7:0] RxD_data;
  async_receiver RX(.clk(clk), .RxD(uart_rx), .RxD_data_ready(RxD_data_ready), .RxD_data(RxD_data));
  always @(posedge clk) if(RxD_data_ready) LED <= RxD_data;

  async_transmitter TX(.clk(clk), .TxD(uart_tx), .TxD_start(RxD_data_ready), .TxD_data(RxD_data));

endmodule
