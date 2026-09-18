module control (
    input  wire       clk,
    input  wire       reset,
    input  wire       en,      // freezes the state register (HALT / flashing)
    input  wire [7:0] ir_out,
    input  wire [7:0] reg_f_out,   // bit0=carry, bit1=negative, bit2=zero, bit3=overflow

    // External input / output
    output reg        ext_in_wr,
    output reg        ext_in_en,
    output reg        ext_out_wr,

    // Destination general-purpose register (A..C): a single select+wr pair
    // instead of one wr per register, to scale without exploding the port
    // count.
    output reg [2:0]  reg_dest_sel,
    output reg        reg_dest_wr,

    // Flags register
    output reg        reg_f_wr,

    // ALU
    output reg [2:0]  alu_sel_a,
    output reg [2:0]  alu_sel_b,
    output reg [2:0]  alu_op,
    output reg        alu_out_wr,
    output reg        alu_out_en,

    // Output to bus from A..C
    output reg [2:0]  bus_out_sel,
    output reg        bus_out_en,

    // Program Counter
    output reg        pc_wr,
    output reg        pc_sel,

    // Memory: where the address comes from (0 = embedded in the opcode
    // byte, for LD/ST -- see FAM_LD_*/FAM_ST_* below; 1 = PC)
    output reg        mem_addr_sel,
    output reg        mem_wr,
    output reg        mem_out_en,

    // Instruction Register
    output reg        ir_wr,

    // Halt
    output reg        halt
);

    // ---- General-purpose registers ----
    localparam [2:0] REG_A = 3'd0;
    localparam [2:0] REG_B = 3'd1;
    localparam [2:0] REG_C = 3'd2;
    // 3'd3..3'd7 invalid where a register field is expected: fall into the
    // default of each case (no-op).

    // ---- Opcodes: family in ir_out[7:3], register/condition/address in ir_out[2:0] ----
    // OP_NOP (8'h00) needs no named constant: it's whatever falls into the
    // `default` case below that isn't OP_HLT.
    localparam [7:0] OP_HLT = 8'hFF;

    // LD/ST are single-byte instructions: the address is embedded directly
    // in ir_out[2:0] (0-7), instead of being fetched as a second byte --
    // halves their footprint in memory. Since the register field would
    // otherwise have to double up as the address (no room for both in 3
    // bits), each destination/source register gets its own opcode family
    // instead (LD_A/LD_B/LD_C, ST_A/ST_B/ST_C) -- there's plenty of spare
    // family space (16 of 32 used) so no register loses addressability or
    // becomes unreachable. See DESIGN.md's area-cut notes.
    localparam [4:0] FAM_LD_A   = 5'd1;  // 0x08-0x0F: A <- mem[addr]
    localparam [4:0] FAM_LD_B   = 5'd2;  // 0x10-0x17: B <- mem[addr]
    localparam [4:0] FAM_LD_C   = 5'd3;  // 0x18-0x1F: C <- mem[addr]
    localparam [4:0] FAM_ST_A   = 5'd4;  // 0x20-0x27: mem[addr] <- A
    localparam [4:0] FAM_ST_B   = 5'd5;  // 0x28-0x2F: mem[addr] <- B
    localparam [4:0] FAM_ST_C   = 5'd6;  // 0x30-0x37: mem[addr] <- C
    localparam [4:0] FAM_ADD    = 5'd7;  // 0x38-0x3C: A <- A + reg
    localparam [4:0] FAM_SUB    = 5'd8;  // 0x40-0x44: A <- A - reg
    localparam [4:0] FAM_AND    = 5'd9;  // 0x48-0x4C: A <- A & reg
    localparam [4:0] FAM_OR     = 5'd10; // 0x50-0x54: A <- A | reg
    localparam [4:0] FAM_XOR    = 5'd11; // 0x58-0x5C: A <- A ^ reg
    localparam [4:0] FAM_OUT    = 5'd12; // 0x60-0x64: external_output <- reg
    localparam [4:0] FAM_IN     = 5'd13; // 0x68-0x6C: reg <- external_input
    localparam [4:0] FAM_JCC    = 5'd14; // 0x70-0x76: jump (conditional, per field), still 2 bytes
    localparam [4:0] FAM_SINGLE = 5'd15; // 0x78-0x7A: NOT/SHL/SHR (operate on A)
    localparam [4:0] FAM_CMP    = 5'd16; // 0x80-0x84: flags <- A - reg (A untouched)

    localparam [2:0] SINGLE_NOT = 3'b000;
    localparam [2:0] SINGLE_SHL = 3'b001;
    localparam [2:0] SINGLE_SHR = 3'b010;

    localparam [2:0] COND_ALWAYS = 3'b000; // JMP
    localparam [2:0] COND_Z      = 3'b001; // JZ
    localparam [2:0] COND_NZ     = 3'b010; // JNZ
    localparam [2:0] COND_C      = 3'b011; // JC
    localparam [2:0] COND_NC     = 3'b100; // JNC
    localparam [2:0] COND_N      = 3'b101; // JN
    localparam [2:0] COND_O      = 3'b110; // JO
    // 3'b111 reserved: never jumps

    localparam [2:0] ALU_ADD = 3'b000;
    localparam [2:0] ALU_SUB = 3'b001;
    localparam [2:0] ALU_AND = 3'b010;
    localparam [2:0] ALU_OR  = 3'b011;
    localparam [2:0] ALU_XOR = 3'b100;
    localparam [2:0] ALU_NOT = 3'b101;
    localparam [2:0] ALU_SHL = 3'b110;
    localparam [2:0] ALU_SHR = 3'b111;

    wire [4:0] family = ir_out[7:3];
    wire [2:0] field  = ir_out[2:0]; // register, condition, or address, depending on the family

    wire flag_carry    = reg_f_out[0];
    wire flag_negative = reg_f_out[1];
    wire flag_zero     = reg_f_out[2];
    wire flag_overflow = reg_f_out[3];

    // Continuous assign, not always@(*)/case: with a case-driven reg here,
    // Icarus was observed to latch an X the first time `field` happened to
    // equal COND_ALWAYS (0) at the same value it already held before any
    // real opcode was fetched, and never re-evaluate afterwards (no
    // apparent value change to re-trigger on). A plain assign has no such
    // re-evaluation ambiguity.
    wire jump_taken = (field == COND_ALWAYS) ? 1'b1 :
                       (field == COND_Z)      ? flag_zero :
                       (field == COND_NZ)     ? ~flag_zero :
                       (field == COND_C)      ? flag_carry :
                       (field == COND_NC)     ? ~flag_carry :
                       (field == COND_N)      ? flag_negative :
                       (field == COND_O)      ? flag_overflow :
                       1'b0; // invalid condition code: never jumps

    // ---- Instruction cycle states ----
    localparam STATE_FETCH1  = 2'b00; // IR <- mem[PC], PC++
    localparam STATE_FETCH2  = 2'b01; // only for FAM_JCC: reads the target address, PC++/PC<-target
    localparam STATE_EXECUTE = 2'b10;
    localparam STATE_STORE   = 2'b11;

    reg [1:0] state;

    // Only conditional/unconditional jumps still need a second byte now:
    // LD/ST embed their address in the opcode itself (see FAM_LD_*/FAM_ST_*
    // above). ir_out is already loaded with the opcode on the negedge
    // inside STATE_FETCH1, so this decision doesn't need to wait an extra
    // cycle.
    wire needs_operand = (family == FAM_JCC);

    // Synchronous reset, matching register.sv's reset style elsewhere in
    // the design.
    always @(posedge clk) begin
        if (reset)
            state <= STATE_FETCH1;
        else if (en) begin
            case (state)
                STATE_FETCH1:  state <= needs_operand ? STATE_FETCH2 : STATE_EXECUTE;
                STATE_FETCH2:  state <= STATE_EXECUTE;
                STATE_EXECUTE: state <= STATE_STORE;
                STATE_STORE:   state <= STATE_FETCH1;
                default:       state <= STATE_FETCH1;
            endcase
        end
    end

    always @(*) begin
        // Default values: everything off
        ext_in_wr    = 0;
        ext_in_en    = 0;
        ext_out_wr   = 0;

        reg_dest_sel = 3'b000;
        reg_dest_wr  = 0;

        reg_f_wr     = 0;

        alu_sel_a    = 3'b000;
        alu_sel_b    = 3'b000;
        alu_op       = 3'b000;
        alu_out_wr   = 0;
        alu_out_en   = 0;

        bus_out_sel  = 3'b000;
        bus_out_en   = 0;

        pc_wr        = 0;
        pc_sel       = 0;

        mem_addr_sel = 1'b1; // default: fetch address (PC)
        mem_wr       = 0;
        mem_out_en   = 0;

        ir_wr        = 0;

        halt         = 0;

        case (state)

            // ---- 1. Fetch opcode: IR <- mem[PC], PC <- PC+1 ----
            STATE_FETCH1: begin
                mem_addr_sel = 1'b1; // PC
                mem_out_en   = 1;
                ir_wr        = 1;
                pc_sel       = 1;    // selects pc_plus_one
                pc_wr        = 1;
            end

            // ---- 1b. Fetch the jump target byte and resolve it (only FAM_JCC reaches this) ----
            STATE_FETCH2: begin
                mem_addr_sel = 1'b1; // PC
                mem_out_en   = 1;
                if (jump_taken) begin
                    pc_sel = 1'b0; // bus (target address) -> PC, without incrementing
                    pc_wr  = 1'b1;
                end else begin
                    pc_sel = 1'b1; // condition not met: continue sequentially
                    pc_wr  = 1'b1;
                end
            end

            // ---- 2. Decode / Execute ----
            STATE_EXECUTE: begin
                case (family)
                    FAM_LD_A, FAM_LD_B, FAM_LD_C,
                    FAM_ST_A, FAM_ST_B, FAM_ST_C,
                    FAM_JCC: begin
                        // LD/ST finish in STORE; JCC already resolved in FETCH2. Nothing to do.
                    end
                    FAM_ADD: begin
                        alu_sel_a  = REG_A;
                        alu_sel_b  = field;
                        alu_op     = ALU_ADD;
                        alu_out_wr = 1;
                        reg_f_wr   = 1;
                    end
                    FAM_SUB: begin
                        alu_sel_a  = REG_A;
                        alu_sel_b  = field;
                        alu_op     = ALU_SUB;
                        alu_out_wr = 1;
                        reg_f_wr   = 1;
                    end
                    FAM_AND: begin
                        alu_sel_a  = REG_A;
                        alu_sel_b  = field;
                        alu_op     = ALU_AND;
                        alu_out_wr = 1;
                        reg_f_wr   = 1;
                    end
                    FAM_OR: begin
                        alu_sel_a  = REG_A;
                        alu_sel_b  = field;
                        alu_op     = ALU_OR;
                        alu_out_wr = 1;
                        reg_f_wr   = 1;
                    end
                    FAM_XOR: begin
                        alu_sel_a  = REG_A;
                        alu_sel_b  = field;
                        alu_op     = ALU_XOR;
                        alu_out_wr = 1;
                        reg_f_wr   = 1;
                    end
                    FAM_CMP: begin
                        // same as SUB, but the result is discarded: only the flags remain
                        alu_sel_a = REG_A;
                        alu_sel_b = field;
                        alu_op    = ALU_SUB;
                        reg_f_wr  = 1;
                    end
                    FAM_OUT: begin
                        bus_out_sel = field;
                        bus_out_en  = 1;
                        ext_out_wr  = 1;
                    end
                    FAM_IN: begin
                        ext_in_wr = 1; // captures external_input -> reg_ext_in
                    end
                    FAM_SINGLE: begin
                        alu_sel_a = REG_A;
                        case (field)
                            SINGLE_NOT: alu_op = ALU_NOT;
                            SINGLE_SHL: alu_op = ALU_SHL;
                            SINGLE_SHR: alu_op = ALU_SHR;
                            default:    alu_op = ALU_NOT; // invalid field: should not happen
                        endcase
                        alu_out_wr = 1;
                        reg_f_wr   = 1;
                    end
                    default: begin
                        // OP_NOP, OP_HLT (don't fall into any family) and unknown opcodes
                        if (ir_out == OP_HLT)
                            halt = 1;
                    end
                endcase
            end

            // ---- 3. Store ----
            STATE_STORE: begin
                case (family)
                    FAM_LD_A: begin
                        mem_addr_sel = 1'b0; // embedded address (ir_out[2:0])
                        mem_out_en   = 1;
                        reg_dest_sel = REG_A;
                        reg_dest_wr  = 1;
                    end
                    FAM_LD_B: begin
                        mem_addr_sel = 1'b0;
                        mem_out_en   = 1;
                        reg_dest_sel = REG_B;
                        reg_dest_wr  = 1;
                    end
                    FAM_LD_C: begin
                        mem_addr_sel = 1'b0;
                        mem_out_en   = 1;
                        reg_dest_sel = REG_C;
                        reg_dest_wr  = 1;
                    end
                    FAM_ST_A: begin
                        bus_out_sel  = REG_A;
                        bus_out_en   = 1;
                        mem_addr_sel = 1'b0;
                        mem_wr       = 1;
                    end
                    FAM_ST_B: begin
                        bus_out_sel  = REG_B;
                        bus_out_en   = 1;
                        mem_addr_sel = 1'b0;
                        mem_wr       = 1;
                    end
                    FAM_ST_C: begin
                        bus_out_sel  = REG_C;
                        bus_out_en   = 1;
                        mem_addr_sel = 1'b0;
                        mem_wr       = 1;
                    end
                    FAM_ADD, FAM_SUB, FAM_AND, FAM_OR, FAM_XOR, FAM_SINGLE: begin
                        // ALU result (already computed in EXECUTE) -> A
                        alu_out_en   = 1;
                        reg_dest_sel = REG_A;
                        reg_dest_wr  = 1;
                    end
                    FAM_IN: begin
                        ext_in_en    = 1; // reg_ext_in -> bus
                        reg_dest_sel = field;
                        reg_dest_wr  = 1;
                    end
                    default: begin
                        // NOP, CMP, OUT, JMP/Jcc, HLT: nothing else
                    end
                endcase
            end

            default: begin end
        endcase
    end

endmodule
