module top (
	input  clk,
	output [7:0] LED
);

	localparam BITS = 8;
	localparam LOG2DELAY = 19;

	reg [BITS+LOG2DELAY-1:0] counter = 0;
	reg [BITS-1:0] outcnt;

	always@(posedge clk) begin
		counter <= counter + 1;
		outcnt <= counter >> LOG2DELAY;
	end

	assign LED = outcnt;
endmodule
