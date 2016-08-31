@ ECE-372, Project 4, 08/06/2015
@ Casimir Sowinski
@ LCD Display Driver
@ This program initializes the I2C system on the BBB and cofigures Sitronix ST7036 LCD. 
@ It a message over I2C to print characters to the screen

.text
.global _start

_start:	
@------------------------------------------------------------------------------------------
@--------------------------------------------------------------------------------Initialize
@------------------------------------------------------------------------------------------
	@----------------------------------------------------------------------------Init stack
	@ Set up SVC stack
	LDR		R13, =STACK1		@ Point to base of STACK1 for SVC mode
	ADD 	R13, R13, #0x1000	@ Point to top of STACK1
	@ Set up IRQ stack
	CPS 	#0x12 				@ Switch to IRQ mode
	LDR		R13, =STACK2 		@ Point to STACK2 for IRQ mode
	CPS 	#0x13 				@ Switch to SVC mode
	@------------------------------------------------------------------------------Init I2C	
	@ Turn on I2C clock
	LDR		R0, =0x44E00048 	@ Load address for CM_PER+CM_PER_I2C1_CLKCTRL
	MOV		R2, #0x02			@ Value for enable
	STRB	R2, [R0]			@ Write value to register
	@ Change pin modes
	LDR		R0, =0x44E1095C		@ Load address for control module+conf_spi0_cs0
	MOV		R2, #0x6A			@ Value for Mode2/slow slew/Rx en/disable pullup/pulldown
	STRB	R2, [R0]			@ Write value to register 
	LDR		R0, =0x44E10958		@ Load address for control module+conf_spi0_d
	STRB	R2, [R0]			@ Write value to register
	@ Software reset 
	LDR		R0, =0x4802A010		@ Load address for I2C+I2C_SYSC
	MOV		R2, #0x02			@ Value to set bit-2/SRST
	STRB	R2, [R0]			@ Write value to register
	@ Scale I2C clock to 12MHz
	LDR		R0, =0x4802A0B0 	@ Load address for I2C+I2C_PSC
	MOV		R2, #0x03			@ Value to scale by 4
	STRB	R2, [R0]			@ Write value to register
	@ Set data rate to 100Kbps, 50% duty cycle
	LDR		R0, =0x4802A0B4		@ Load address of I2C+I2C_SCLL
	MOV		R2, #0x35			@ Value for SCLL
	STRB	R2, [R0]			@ Write value to register 
	LDR		R0, =0x4802A0B8		@ Load address of I2C+I2C_SCLH
	MOV		R2, #0x37			@ Value for SCLH
	STRB	R2, [R0]			@ Write value to register 
	@ Set address in I2C_OA
	LDR		R0, =0x4802A0A8 	@ Load address for I2C+I2C_OA
	MOV		R2, #0x00			@ Value for own address
	STRB	R2, [R0]			@ Write value to register
	@ Take I2C out of reset, Set as master, transmitter mode, 8-bit data
	@ Set bits 9 and 10
	LDR		R0, =0x4802A0A4 	@ Load address for I2C+I2C_CON
	MOV		R2, #0x8600			@ Value for bits 9, 10, 15
	STR		R2, [R0]			@ Write value to register {Reset seen in I2C_SYSS here}
	@ Set number of bytes to transfer
	LDR		R0, =0x4802A098  	@ Load address for I2C+I2C_CNT
	MOV		R2, #0x0A			@ Value for bits 0-15/DCOUNT:10_D characters
	STRB	R2, [R0]			@ Write value to register	
	@ Set slave address to 0111100_2 (0x3C)
	LDR		R0, =0x4802A0AC 	@ Load address for I2C+I2C_SA
	MOV		R2, #0x3C			@ Value for bits 0-6/SA:0111100_2
	STR		R2, [R0]			@ Write value to register 	
	@ Clear interrupts
	LDR		R0, =0x4802A028		@ Load address for I2C+I2C_IRQSTATUS
	LDR		R2, =0x7FFF			@ Load address for value to clear interrupts
	STR		R2, [R0]			@ Write value to register
	NOP
	
@------------------------------------------------------------------------------------------
@-----------------------------------------------------------------------------------Message
@------------------------------------------------------------------------------------------
	BL		POLL_BB				@ Poll the BB	
	BL		START				@ Initiate a START condition
@-------------------------------------------------------------------------Send Instructions	
	MOV		R3, #0x00			@ Initialize instruction offset value
SEND_INST:	
	BL		WAIT				@ Delay 
	BL		POLL_XRDY			@ Poll
	
	BL		WAIT				@ Delay 
	@ Get instruction
	LDR		R0, =INST_DATA		@ Load pointer to INST_DATA
	LDRB	R1, [R0, R3]		@ Load current intruction
	ADD		R3, R3, #0x01		@ Increment instruction offset value
	
	BL		WAIT				@ Delay 	
	@ Store instruction
	LDR		R0, =0x4802A09C		@ Load address of I2C+I2C_DATA
	STRB	R1, [R0]			@ Write value to register 
	
	BL		WAIT				@ Delay 
	@ Clear XRDY
	BL		CLEAR_XRDY			@ Clear XRDY bit
	
	BL		WAIT				@ Delay 
	@ Check if payload transferred
	LDR		R0, =0x4802A024		@ Load address of I2C+I2C_IRQSTATUS_RAW
	LDR		R1, [R0]			@ Load value in register
	MOV		R4, #0x04			@ Mask for bit-4/ARDY
	AND		R1, R1, R4			@ Mask to get bit-4/ARDY
	MOV		R2, #0x04			@ Load value to test bit-2/ARDY
	TST		R1, R2	
	BEQ		SEND_INST			@ Send more instructions 		
@----------------------------------------------------------------------Initiate 2nd Message
	BL		WAIT				@ Delay 	
	@ Take I2C out of reset, Set as master, transmitter mode, 8-bit data
	LDR		R0, =0x4802A0A4 	@ Load address for I2C+I2C_CON
	MOV		R2, #0x8600			@ Value for bits-15/I2C_EN
	STR		R2, [R0]			@ Write value to register {Reset seen in I2C_SYSS here}
	
	BL		WAIT				@ Delay 	
	@ Set number of bytes to transfer
	LDR		R0, =0x4802A098  	@ Load address for I2C+I2C_CNT
	MOV		R2, #0x2B			@ Value for bits 0-15/DCOUNT:10_D characters
	STRB	R2, [R0]			@ Write value to register	
	
	BL		WAIT				@ Delay 	
	@ Set slave address to 0111100_2 (0x3C)
	LDR		R0, =0x4802A0AC 	@ Load address for I2C+I2C_SA
	MOV		R2, #0x3C			@ Value for bits 0-6/SA:0111100_2
	STRB	R2, [R0]			@ Write value to register 
	
	BL		WAIT				@ Delay 		
	BL		POLL_BB				@ Poll the BB
	BL		WAIT				@ Delay
	BL		START				@ Initate a START condition	
@---------------------------------------------------------------------------Send Characters
	MOV		R3, #0x00			@ Initialize instruction offset value
SEND_CHAR:	
	BL		WAIT				@ Delay 
	BL		POLL_XRDY			@ Poll
	
	BL		WAIT				@ Delay 	
	LDR		R0, =CHAR_DATA		@ Load pointer to INST_DATA
	LDRB	R1, [R0, R3]		@ Load current character
	ADD		R3, R3, #0x01		@ Increment instruction offset value
	
	BL		WAIT				@ Delay 	
	LDR		R0, =0x4802A09C		@ Load address of I2C+I2C_DATA
	STRB	R1, [R0]			@ Write value to register 

	BL		WAIT				@ Delay 
	BL		CLEAR_XRDY			@ Clear XRDY bit
	
	BL		WAIT				@ Delay 		
	@ Check if payload transferred
	LDR		R0, =0x4802A024		@ Load address of I2C+I2C_IRQSTATUS_RAW
	LDR		R1, [R0]			@ Load value in register
	MOV		R4, #0x04			@ Mask for bit-4/ARDY
	AND		R1, R1, R4			@ Mask to get bit-4/ARDY
	MOV		R2, #0x04			@ Load value to test bit-2/ARDY
	TST		R1, R2	
	BEQ		SEND_CHAR			@ Send more instructions 	

	BL		STOP				@ Initate a STOP condition
	NOP
	
@------------------------------------------------------------------------------------------
@---------------------------------------------------------------------------------Functions
@------------------------------------------------------------------------------------------			
POLL_BB:
	@STMFD	R13!, {R0-R2, R14}	@ Push stack
POLL_BB_LOOP:
	@ Poll bit-12/BB, when Busy Bit is clear bus is ready
	LDR 	R0, =0x4802A024 	@ Load address for I2C+I2C_IRQSTATUS_RAW
	LDR		R1, [R0]			@ Load value in address
	LDR		R4, =0x1000			@ Load mask for bit-12/BB
	AND		R1, R4, R1			@ Mask bit-12/BB 
	TST		R1, #0x1000			@ Value to test bit-12/BB [Looking for '1']
	BNE		POLL_BB_LOOP		@ Continue polling if bit not set
	@LDMFD	R13!, {R0-R2, R14}	@ Pop stack
	MOV		PC,	R14				@ Return
START:
	@STMFD	R13!, {R0-R2, R14}	@ Push stack
	@ Initiate a START condition
	LDR 	R0, =0x4802A0A4		@ Load address of I2C+I2C_CON
	LDR		R1, [R0]			@ Load value
	LDR		R2, =0x8603			@ Value for START condition
	STR		R2, [R0]			@ Write value to register
	@LDMFD	R13!, {R0-R2, R14}	@ Pop stack
	MOV		PC,	R14				@ Return
CLEAR_XRDY:
	@STMFD	R13!, {R0-R2, R14}	@ Push stack
	LDR		R0, =0x4802A028		@ Load address of I2C+I2C_IRQSTATUS
	MOV		R1, #0x10			@ Value to set bit-4/XRDY_IE
	STRB	R1, [R0]			@ Write value to register
	@LDMFD	R13!, {R0-R2, R14}	@ Pop stack
	MOV		PC,	R14				@ Return
POLL_XRDY:
	@STMFD	R13!, {R0-R2, R14}	@ Push stack
POLL_XRDY_LOOP:
	@ See if bus is free
	LDR 	R0, =0x4802A024 	@ Load address for I2C+I2C_IRQSTATUS_RAW
	LDRB	R1, [R0]			@ Load value in address
	TST		R1, #0x10			@ Value to test bit-4/XRDY 
	BEQ		POLL_XRDY_LOOP		@ Continue polling if bit not set
	@LDMFD	R13!, {R0-R2, R14}	@ Pop stack
	MOV		PC,	R14				@ Return	
WAIT: 
	@STMFD	R13!, {R0-R2, R14}	@ Push stack
	LDR		R2, =0x1FFFF		@ Load wait value
WAIT_LOOP:
	SUBS	R2, R2, #1			@ Decrement wait counter
	BNE		WAIT_LOOP			@ Return if not done counting
	@LDMFD	R13!, {R0-R2, R14}	@ Pop stack
	MOV		PC,	R14				@ Return				
STOP: 
	@STMFD	R13!, {R0-R2, R14}	@ Push stack
@ Initiate a STOP condition
	LDR		R0, =0x4802A0A4		@ Load address for I2C+I2C_CON
	@MOV		R2, #0x03			@ Value to set bit-1/STT
	LDR		R2, =0x8603			@ Value for START condition
	STR		R2, [R0]			@ Write value to register
	@LDMFD	R13!, {R0-R2, R14}	@ Pop stack
	MOV		PC,	R14				@ Return				
	
@------------------------------------------------------------------------------------------					
@--------------------------------------------------------------------------------------Data
@------------------------------------------------------------------------------------------
@----------------------------------------------------------------------------------Init I2C
.data 
.align 4
INST_DATA:
	.byte	0x00				@ Set RS=0, Co=0
 	.byte	0x38				@ Function set
 	.byte	0x39				@ Function set
 	.byte 	0x14				@ Bias set
 	.byte	0x78				@ Contrast set
 	.byte 	0x5E				@ Power/ICON/Contrast control
 	.byte	0x6D				@ Follower control
 	.byte	0x0C				@ Display ON/OFF control
 	.byte	0x01				@ Clear display
 	.byte	0x06				@ Entry mode set
@-------------------------------------------------------------------------------I2C Message
.align 4
CHAR_DATA: 
	.byte	0x80				@ Initiate
	.byte	0x06				@ Cursor shift to the right	
	.byte	0x40				@ Set the RS bit to indicate character data 
@			C	  a     s     i     m     i     r     _     S     o
	.byte 	0x43, 0x61, 0x73, 0x69, 0x6D, 0x69, 0x72, 0x20, 0x53, 0x6F
 @ 			w     i     n     s     k     i     _     _     _     _
	.byte 	0x77, 0x69, 0x6E, 0x73, 0x6B, 0x69, 0x20, 0x20, 0x20, 0x20 
 @          E     C     E     _     3     7     2     :     _     S
	.byte 	0x45, 0x43, 0x45, 0x20, 0x33, 0x37, 0x32, 0x3A, 0x20, 0x53
 @          u     m     m     e     r     _     2     0     1     5  
	.byte 	0x75, 0x5D, 0x5D, 0x65, 0x72, 0x20, 0x32, 0x30, 0x31, 0x35  

@--------------------------------------------------------------------------------Stack data
.align 4
STACK1:							@ SVC mode stack 
	.rept 	1024
	.word 	0x0000
	.endr
.align 4
STACK2:							@ IRQ mode stack 
	.rept 	1024
	.word 	0x0000
	.endr

.END	
