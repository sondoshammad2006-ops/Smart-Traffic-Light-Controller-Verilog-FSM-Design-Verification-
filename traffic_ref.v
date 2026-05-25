`timescale 1ns/1ps

// Timing  
`define T_MG 60
`define T_SG 40
`define T_PG 40
`define T_Y  4
`define T_AR 2

module traffic_ref(
  input  clk, 
  input  rst,
  input  VS,
  input  PB,
  output reg  [2:0] light_main, // {RED,YEL,GRN}
  output reg  [2:0] light_side, // {RED,YEL,GRN}
  output reg        walk
);

  parameter [2:0] RED = 3'b100;
  parameter [2:0] YEL = 3'b010;
  parameter [2:0] GRN = 3'b001;

  integer t;                
  reg vs_pending, pb_pending;

  reg first_is_vs; // saves who arrived first: 1->VS first, 0->PB first

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      light_main <= GRN;
      light_side <= RED;
      walk       <= 1'b0;
      t          <= 0;         
      vs_pending <= 1'b0;
      pb_pending <= 1'b0;
      first_is_vs <= 1'b1;
    end 
    else begin
	 
      if (!vs_pending && !pb_pending) begin	 // if there's no pending request 
        if (VS && PB)  // if VS and PB came at the same time serve vs first
			first_is_vs <= 1'b1; 
        else if (VS)    // first request is VS
			first_is_vs <= 1'b1;
        else if (PB)   // first request is PB
			first_is_vs <= 1'b0;
      end
	  
	  // requests
      if (VS) 
		  vs_pending <= 1'b1;
      if (PB) 
		  pb_pending <= 1'b1;

      // Case Main green
      if (light_main==GRN && light_side==RED && walk==1'b0) begin
        if (t < (`T_MG-1)) begin
          t <= t + 1;
        end
	  else
		  begin
          if (vs_pending || pb_pending) begin
            light_main <= YEL;
            light_side <= RED;
            walk       <= 1'b0;
            t          <= 0;   
          end
        end
      end

      // Case Main yellow
      else if (light_main==YEL && light_side==RED && walk==1'b0) begin
        if (t < (`T_Y-1)) begin
          t <= t + 1;
        end 
	  else 
		  begin
          light_main <= RED;
          light_side <= RED;
          walk       <= 1'b0;
          t          <= 0;      
        end
      end

      // Case all red (cases both requests arrives at the same time , there's a pending requests from vvs and pb we should know which one should serve first)
      else if (light_main==RED && light_side==RED && walk==1'b0) begin
        if (t < (`T_AR-1)) begin
          t <= t + 1;
        end 
	  else begin
          if (vs_pending && pb_pending) begin // if there's 2 pending requests
            if (first_is_vs) begin	 // and the first one is VS so we will serve it by make the side green and the main red
              light_main  <= RED;
              light_side  <= GRN;
              walk        <= 1'b0;
              vs_pending  <= 1'b0;
              
              if (pb_pending || PB) // after that if remains a PB request serve it 
				  first_is_vs <= 1'b0;
                  t <= 0;   
            end 
			else begin	// if the first is zero that means that the pb comes first 
              light_main  <= RED;
              light_side  <= RED;
              walk        <= 1'b1;
              pb_pending  <= 1'b0;
             
			  // after that if there's a remainig request from vs serve it 
              if (vs_pending || VS) 
				  first_is_vs <= 1'b1;
              t <= 0;   
            end
          end
          else if (vs_pending) begin
            light_main  <= RED;
            light_side  <= GRN;
            walk        <= 1'b0;
            vs_pending  <= 1'b0;
            t           <= 0;   
          end 
		 else if (pb_pending) begin
            light_main  <= RED;
            light_side  <= RED;
            walk        <= 1'b1;
            pb_pending  <= 1'b0;
            t           <= 0;   
          end 
		  else begin
            light_main  <= GRN;
            light_side  <= RED;
            walk        <= 1'b0;
            t           <= 0;   
          end
        end
      end

      // Case Side green
      else if (light_main==RED && light_side==GRN && walk==1'b0) begin
        if (t < (`T_SG-1)) begin
          t <= t + 1;
        end 
	  else begin
          light_main <= RED;
          light_side <= YEL;
          walk       <= 1'b0;
          t          <= 0;     
        end
      end

      // Case side yellow
      else if (light_main==RED && light_side==YEL && walk==1'b0) begin
        if (t < (`T_Y-1)) begin
          t <= t + 1;
        end 
	  else begin
          light_main <= RED;
          light_side <= RED;
          walk       <= 1'b0;
          t          <= 0;      
        end
      end

      // Case walk
      else if (light_main==RED && light_side==RED && walk==1'b1) begin
        if (t < (`T_PG-1)) begin
          t <= t + 1;
        end 
	  else begin
          light_main <= RED;
          light_side <= RED;
          walk       <= 1'b0;
          t          <= 0;      
        end
      end

      // default
      else begin
        light_main <= GRN;
        light_side <= RED;
        walk       <= 1'b0;
        t          <= 0;        
      end
    end
  end

endmodule
