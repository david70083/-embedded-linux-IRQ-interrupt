
.global _start  				


//set interrupt vector table 
_start:  
	ldr pc, =Reset_Handler	 	//0x0	
	ldr pc, =Undefined_Handler	//0x4
	ldr pc, =SVC_Handler		//0x8
	ldr pc, =PrefAbort_Handler	
	ldr pc, =DataAbort_Handler	
	ldr	pc, =NotUsed_Handler	
	ldr pc, =IRQ_Handler		
	ldr pc, =FIQ_Handler	

	
Reset_Handler:

	cpsid i					
	//close D cache and I cache and MMU
	mrc     p15, 0, r0, c1, c0, 0     
    bic     r0,  r0, #(0x1 << 12)     
    bic     r0,  r0, #(0x1 <<  2)     
    bic     r0,  r0, #0x2             
          
    mcr     p15, 0, r0, c1, c0, 0     

	

	//set interrupt vector offset
	ldr r0, =0X87500000
	dsb
	isb
	mcr p15, 0, r0, c12, c0, 0
	dsb
	isb

    
	//IRQ mode
	mrs r0, cpsr
	bic r0, r0, #0x1f 	
	orr r0, r0, #0x12 	
	msr cpsr, r0		
	ldr sp, =0x80600000	

	//SYS mode
	mrs r0, cpsr
	bic r0, r0, #0x1f 	
	orr r0, r0, #0x1f 	
	msr cpsr, r0		
	ldr sp, =0x80400000	

	//SVC mode
	mrs r0, cpsr
	bic r0, r0, #0x1f 	
	orr r0, r0, #0x13 
	msr cpsr, r0		
	ldr sp, =0X80200000	

	cpsie i				


	b main				//move to main.c


Undefined_Handler:
	ldr r0, =Undefined_Handler
	bx r0
	


SVC_Handler:
	ldr r0, =SVC_Handler
	bx r0


PrefAbort_Handler:
	ldr r0, =PrefAbort_Handler	
	bx r0


DataAbort_Handler:
	ldr r0, =DataAbort_Handler
	bx r0


NotUsed_Handler:

	ldr r0, =NotUsed_Handler
	bx r0


IRQ_Handler:
	push {lr}						//push lr register
	push {r0-r3, r12}				//push r0-r3 r12 register

	mrs r0, spsr					//read spsr to r0 register
	push {r0}						//push r0 register

	mrc p15, 4, r1, c15, c0, 0      //read cp15 c0  value to r1 register
								
								
								
	add r1, r1, #0X2000				//shift address to get interrupt ID
	ldr r0, [r1, #0XC]			
								
								
								
	push {r0, r1}					//push r0 r1 register
	
	cps #0x13					    //move to  SVC mode
	
	push {lr}						//push lr register
	
	ldr r2, =system_irqhandler		//read interrupt function address to r2 register
	blx r2							//run r2 register

	pop {lr}						//recover lr register 
	cps #0x12						//move to IRQ mode
	pop {r0, r1}				
	str r0, [r1, #0X10]				//when interrupt done, write 0x10 to EOIR

	pop {r0}						
	msr spsr, r0				    //recover spsr register

	pop {r0-r3, r12}		
	pop {lr}				
	subs pc, lr, #4			
	
	

FIQ_Handler:

	ldr r0, =FIQ_Handler	
	bx r0							
