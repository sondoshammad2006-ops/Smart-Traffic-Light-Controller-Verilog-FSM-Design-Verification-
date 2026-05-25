`timescale 1ns/1ps

module tb_compare;

  reg clk, rst, VS, PB;

  // RTL outputs
  wire [2:0] rtl_light_main;
  wire [2:0] rtl_light_side;
  wire       rtl_walk;

  // REF outputs
  wire [2:0] ref_light_main;
  wire [2:0] ref_light_side;
  wire       ref_walk;

  integer t;

  //  RTL 
  traffic_ctrl rtl_u (
    .clk(clk),
    .rst(rst),
    .VS(VS),
    .PB(PB),
    .light_main(rtl_light_main),
    .light_side(rtl_light_side),
    .walk(rtl_walk)
  );

  //  REF 
  traffic_ref ref_u (
    .clk(clk),
    .rst(rst),
    .VS(VS),
    .PB(PB),
    .light_main(ref_light_main),
    .light_side(ref_light_side),
    .walk(ref_walk)
  );					

  initial clk = 1'b0;
  always #2 clk = ~clk;   
			  
  always @(posedge clk) begin
    if (rst) 
		t <= 0;
    else    
		t <= t + 1;
  end

  always @(negedge clk) begin
    if (!rst) begin
      if (rtl_light_main !== ref_light_main ||
          rtl_light_side !== ref_light_side ||
          rtl_walk       !== ref_walk)
		  begin

        $display("=== MISMATCH at t=%0d ===", t);
        $display("Inputs: VS=%b PB=%b rst=%b", VS, PB, rst);
        $display("RTL: main=%b side=%b walk=%b", rtl_light_main, rtl_light_side, rtl_walk);
        $display("REF: main=%b side=%b walk=%b", ref_light_main, ref_light_side, ref_walk);

        $stop;
      end
    end
  end

  initial begin
    rst = 1; VS = 0; PB = 0;
    t = 0;

    //  1) Reset
    repeat(2) @(posedge clk);
    rst = 0;

  
    repeat(20) @(posedge clk);

    // 2) PB only 
    PB = 1;  
	repeat(1) @(posedge clk); 
	PB = 0;

    repeat(40) @(posedge clk);

    // 3) VS only
    VS = 1;  
	repeat(1) @(posedge clk);  
	VS = 0;
			  
    repeat(40) @(posedge clk);

    // 4) PB then VS (PB should be served first) 
    PB = 1;  
	repeat(1) @(posedge clk);  
	PB = 0;
    repeat(5) @(posedge clk);
    VS = 1;  
	repeat(1) @(posedge clk);  
	VS = 0;

    repeat(120) @(posedge clk);

    // 5) VS and PB together (VS should be served first) 
    VS = 1; PB = 1;  repeat(1) @(posedge clk);  VS = 0; PB = 0;

    repeat(100) @(posedge clk);

    // 6) Reset again 
    rst = 1; @(posedge clk); rst = 0;
	 repeat(100) @(posedge clk);
   

    $display("PASS: RTL matches REF. t=%0d", t);
    $finish;
  end

endmodule
