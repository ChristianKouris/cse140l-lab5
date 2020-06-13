// CSE140L -- lab 5
// applies done flag when cycle_ct = 255
module top_level5(
  input        clk, init, 
  output logic done);
  logic[5:0] LFSR[64];               // LFSR states
  logic[5:0] LFSR_ptrn[6];           // the 6 possible maximal length LFSR patterns
  logic[5:0] start;           // LFSR initial state temp register
  logic[5:0] lfsr_trial[6];       // 6 possible LFSR match trials, each 7 cycles deep
  int        km;                     // number of ASCII _ in front of decoded message
  assign LFSR_ptrn[0] = 6'h21;
  assign LFSR_ptrn[1] = 6'h2D;
  assign LFSR_ptrn[2] = 6'h30;
  assign LFSR_ptrn[3] = 6'h33;
  assign LFSR_ptrn[4] = 6'h36;
  assign LFSR_ptrn[5] = 6'h39;
  logic[7:0] foundit;                // got a match for LFSR
  logic      write_en;               // data memory write enable
  logic[7:0] raddr,                  // read address pointer
             waddr;                  // write address pointer
  logic[7:0] data_in;                // to dat_mem
  wire [7:0] data_out;               // from dat_mem
  logic[7:0] ct_inc;                 // prog count step (default = +1)
  logic[7:0] ct;
  logic[7:0] mem_ct;
  logic      load_LFSR;              // copy taps and start into LFSR
  logic      start_en;
  logic      LFSR6_en;
  logic      LFSR_en;  
  logic      eureka_en;
  logic      firstcore_en;
  logic      underscore_en;
  logic      secondcore_en;

  dat_mem dm1(.clk, .write_en, .raddr, .waddr,
            .data_in, .data_out);
				
  //initialize the 6 trial LFSRs for each unique LFSR_ptrn
  lfsr6 l60(.clk, .en(LFSR_en), .init(load_LFSR),
         .taps(LFSR_ptrn[0]), .start, .state(lfsr_trial[0]));
  lfsr6 l61(.clk, .en(LFSR_en), .init(load_LFSR),
         .taps(LFSR_ptrn[1]), .start, .state(lfsr_trial[1]));
  lfsr6 l62(.clk, .en(LFSR_en), .init(load_LFSR),
         .taps(LFSR_ptrn[2]), .start, .state(lfsr_trial[2]));
  lfsr6 l63(.clk, .en(LFSR_en), .init(load_LFSR),
         .taps(LFSR_ptrn[3]), .start, .state(lfsr_trial[3]));
  lfsr6 l64(.clk, .en(LFSR_en), .init(load_LFSR),
         .taps(LFSR_ptrn[4]), .start, .state(lfsr_trial[4]));
  lfsr6 l65(.clk, .en(LFSR_en), .init(load_LFSR),
         .taps(LFSR_ptrn[5]), .start, .state(lfsr_trial[5]));
			
  always_comb begin
// list defaults here; case needs list only exceptions
  done      = 'b0;
  write_en  = 'b0;         // data memory write enable  
  raddr     = 'b0;         
  waddr     = 'b0;
  data_in   = 'b0;
  load_LFSR = 'b0;
//all of the enables
  start_en      = 'b0;
  LFSR6_en      = 'b0;
  LFSR_en       = 'b0;
  eureka_en     = 'b0;
  firstcore_en  = 'b0;
  underscore_en = 'b0;
  secondcore_en = 'b0;
// PC normally advances by 1
// override to go back in a subroutine or forward/back in a branch
  ct_inc        = 'b1;         // PC normally advances by 1
  case(ct)
    0,1: begin   end       // no op to wait for things to settle from init
    2:   begin
           raddr      = 'd64;
           start_en   = 'b1;
         end
	 3:   begin
	        load_LFSR  = 'b1;
			end
	 4:   begin             // load LFSRs from core 64 + 0-6
			  ct_inc     = 'b0;
			  LFSR6_en   = 'b1;
			  raddr      = mem_ct + 64;
         end
	 5,6,7,8,9,10:   begin
			  //advancing the trial LSFRs 6 times after the start
			  LFSR_en    = 'b1;
			end
	 11:  begin
	        eureka_en  = 'b1;
			end
	 12:  begin
	        firstcore_en  = 'b1;
			  ct_inc        = 'b0;
			  raddr         = mem_ct + 'd64 - 'd7;
			  waddr         = mem_ct - 'd7;
			  write_en      = 'b1;
			  data_in       = data_out^{2'b0,LFSR[mem_ct-7]};
			  $display("%dth core = %h LFSR = %h",mem_ct,data_out,LFSR[mem_ct-7]);
	      end
	 14:  begin
	        underscore_en = 'b1;
			  ct_inc        = 'b0;
			  raddr         = mem_ct;
			end
	 16:  begin
	        secondcore_en = 'b1;
			  ct_inc        = 'b0;
			  raddr         = mem_ct + km;
			  waddr         = mem_ct;
			  write_en      = 'b1;
			  data_in       = data_out;
			  $display("%dth core = %h",mem_ct,data_in);
			end
	 17:  begin
	        done          = 'b1;
			end
	 default: begin end
  endcase
end 

  always @(posedge clk) begin  :clock_loop
    if(init) begin
	  ct <= 'b0;
	  mem_ct <= 'b0;
	 end
	 else ct <= ct + ct_inc;
	 
	 //getting the start state for LFSRs
	 if(start_en)
    start   <= data_out[5:0]^6'h1f;
	 
	 //loading in the LSFR data for the encryption
	 if( LFSR6_en ) begin
	   LFSR[mem_ct] = data_out[5:0]^6'h1f;
		mem_ct <= mem_ct + 'b1;
		if( mem_ct == 6 ) begin
		  mem_ct <= 7;
		  ct <= ct + 'b1;
		end
	 end
	 
	 //using the eureka function on the LFSRs with 6 different patterns
	 if( eureka_en ) begin
		  for(int mm=0;mm<6;mm++) begin :ureka_loop  
            $display("mm = %d  lfsr_trial[mm] = %h, LFSR[6] = %h",
			     mm, lfsr_trial[mm], LFSR[6]); 
		    if(lfsr_trial[mm] == LFSR[6]) begin
			  foundit = mm;
			  $display("foundit = %d LFSR[6] = %h",foundit,LFSR[6]);
            end
		  end :ureka_loop
		  $display("foundit fer sure = %d",foundit);
		  //filling in the rest of the LFSR states for the encryption
		  for(int jm=0;jm<63;jm++) LFSR[jm+1] = (LFSR[jm]<<1)+(^(LFSR[jm]&LFSR_ptrn[foundit]));
	 end

	 //writing to the core for the first time
    if( firstcore_en ) begin
		mem_ct <= mem_ct + 'b1;
		if( mem_ct == 64-8 ) begin
		  mem_ct <= 0;
		  ct <= ct + 'b1;
		end
      #10ns;
	 end	
	 
	 //detecting where there is no underscore
    if( underscore_en ) begin
		if( data_out == 8'h5f ) begin
		  mem_ct <= mem_ct + 'b1;
		end
		else begin
		  km <= mem_ct;
		  mem_ct <= 'd0;
		  ct <= ct + 'b1;
		  $display("underscores to %d th",mem_ct);
		end
		if( mem_ct == 'd64 ) begin
		  mem_ct <= 'd0;
		  ct <= ct + 'b1;
		end   
	 end
	 
	 //the final write to the core with the decrypted message with no preamble
	 if( secondcore_en ) begin
		mem_ct <= mem_ct + 'b1;
		if( mem_ct == 'd63 ) begin
		  ct <= ct + 'b1;
		end			
	 end	 
         
  end  :clock_loop

endmodule