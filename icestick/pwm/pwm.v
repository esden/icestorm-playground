module top(
	input clk,
	output LED1,
	output LED2,
	output LED3,
	output LED4,
	output LED5,
);

	reg [23:0] cnt;

	always @(posedge clk) cnt<=cnt+1;
	wire [3:0] PWM_input = cnt[23] ? cnt[22:19] : ~cnt[22:19];    // ramp the PWM input up and down

	reg [4:0] PWM;
	always @(posedge clk) PWM <= PWM[3:0]+PWM_input;

	assign {LED1, LED2, LED3, LED4, LED5} = PWM[4] ? 'b10100 : 'b01011;
endmodule
