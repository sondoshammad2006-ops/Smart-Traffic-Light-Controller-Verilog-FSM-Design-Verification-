`timescale 1ns/1ps

module traffic_ctrl (
  input clk, rst,
  input VS, PB,                 // Vehicle sensor and push button
  output reg [2:0] light_main,  // {RED,YEL,GRN}
  output reg [2:0] light_side,  // {RED,YEL,GRN}
  output reg walk               // pedestrian walk signal
);

  // lights
  parameter [2:0] Red    = 3'b100;
  parameter [2:0] Yellow = 3'b010;
  parameter [2:0] Green  = 3'b001;

  // timers 
  integer T_Mg     = 60;
  integer T_Sg     = 40;
  integer T_Pg     = 40;
  integer T_Yellow = 4;   
  integer T_Red    = 2;

  // states
  parameter [2:0]
    ST_MG = 3'd0,
    ST_MY = 3'd1,
    ST_AR = 3'd2,
    ST_SG = 3'd3,
    ST_SY = 3'd4,
    ST_PG = 3'd5;

  reg [2:0] state, next_state;

  // pending flags
  reg vs_pending;
  reg pb_pending;

  // who arrived first to serve it 
  reg first_is_vs;

  wire any_req = (vs_pending | pb_pending);

  // timer counter
  reg [15:0] t;

  // remember from which state we entered AR 
  reg [2:0] ar_from, ar_from_next;

  // Pending requests queue
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      vs_pending   <= 1'b0;
      pb_pending   <= 1'b0;
      first_is_vs  <= 1'b1;
    end
    else begin
      // decide who is first when no pending exists yet
      if (!vs_pending && !pb_pending) begin
        if (VS && PB)  // if VS and PB came at the same cycle the priority to serve is for vs
          first_is_vs <= 1'b1; 
        else if (VS)   // if just exist vs serve it
          first_is_vs <= 1'b1;
        else if (PB)   // if just exist PB serve it
          first_is_vs <= 1'b0;
      end

      // requests
      vs_pending <= (vs_pending | VS);
      pb_pending <= (pb_pending | PB);

      // to clear the pending requests when we start to serve them
      // if we aren't in the SG and the nextstate we will go to SG that means that we will serve the VS
      if (state != ST_SG && next_state == ST_SG) begin
        vs_pending <= 1'b0;
        // if PB still pending after serving VS, make PB next
        if (pb_pending | PB) 
          first_is_vs <= 1'b0;
      end

      if (state != ST_PG && next_state == ST_PG) begin
        pb_pending <= 1'b0;
        // if VS still pending after serving PB, make VS next
        if (vs_pending | VS) 
          first_is_vs <= 1'b1;
      end
    end
  end

  // State register 
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state   <= ST_MG;
      t       <= 16'd0;
      ar_from <= ST_MG;
    end 
    else begin
      state <= next_state;

      // timer: reset on state change, increment otherwise
      // NOTE: in MG if no requests, after reaching 59 we reset back to 0 (so it keeps showing 0..59)
      if (next_state != state) begin
        t <= 16'd0;
      end
      else begin
        t <= t + 16'd1;
      end

      // save entry source into AR
      if (next_state != state && next_state == ST_AR)
        ar_from <= ar_from_next;
    end
  end

  // Next-state  
  always @(*) begin
    next_state   = state;
    ar_from_next = ar_from;	// to know the source of ar 

    case (state)

      // Main green
      ST_MG: begin
        if (t >= (T_Mg-1)) begin
          if (any_req) 
			  next_state = ST_MY;
          else         
			  next_state = ST_MG;  
        end 
        else begin // if time less than 60 it will stay in MG
          next_state = ST_MG;
        end
      end

      // Main yellow
      ST_MY: begin
        if (t >= (T_Yellow-1)) begin
          next_state   = ST_AR;
          ar_from_next = ST_MY;
        end 
        else begin
          next_state = ST_MY;
        end
      end

      // All red (serve first come first served, and if both come at the same time sereve VS)
      ST_AR: begin
        if (t >= (T_Red-1)) begin
          if (vs_pending && pb_pending)
			  if(first_is_vs)
				  next_state=ST_SG;
			  else
				  next_state=ST_PG;
          else if (vs_pending)
            next_state = ST_SG;
          else if (pb_pending)
            next_state = ST_PG;
          else
            next_state = ST_MG;
        end 
        else begin
          next_state = ST_AR;
        end
      end

      // Side green
      ST_SG: begin
        if (t >= (T_Sg-1)) 
			next_state = ST_SY;
        else              
			next_state = ST_SG;
      end

      // Side yellow
      ST_SY: begin
        if (t >= (T_Yellow-1)) begin
          next_state   = ST_AR;
          ar_from_next = ST_SY;
        end 
        else begin
          next_state = ST_SY;
        end
      end

      // Ped walk
      ST_PG: begin
        if (t >= (T_Pg-1)) begin
          next_state   = ST_AR;
          ar_from_next = ST_PG;
        end 
        else begin
          next_state = ST_PG;
        end
      end

      default: begin
        next_state = ST_MG;
      end
    endcase
  end

  // Output logic			   
  always @(*) begin
    light_main = Green;
    light_side = Red;
    walk       = 1'b0;

    case (state)
      ST_MG: begin 
	  light_main = Green;  
	  light_side = Red;   
	  walk = 1'b0; 
	  end 
	  
      ST_MY: begin 
	  light_main = Yellow; 
	  light_side = Red;   
	  walk = 1'b0; 
	  end	  
	  
      ST_AR: begin 
	  light_main = Red;    
	  light_side = Red;    
	  walk = 1'b0; 
	  end	   
	  
      ST_SG: begin 
	  light_main = Red;    
	  light_side = Green;  
	  walk = 1'b0; 
	  end	   
	  
      ST_SY: begin 
	  light_main = Red;    
	  light_side = Yellow; 
	  walk = 1'b0; 
	  end		   
	  
      ST_PG: begin 
	  light_main = Red;    
	  light_side = Red;    
	  walk = 1'b1; 
	  end
    endcase
  end

endmodule
